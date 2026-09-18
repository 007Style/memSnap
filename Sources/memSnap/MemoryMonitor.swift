import Foundation
import SwiftUI
import Combine
import Darwin
import IOKit

// ═══════════════════════════════════════════════════════════════════════════════
// MemoryMonitor.swift — 1 Hz memory sampling singleton
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - PressureLevel

enum PressureLevel: String, CaseIterable, Comparable {
    case normal   = "Normal"
    case elevated = "Elevated"
    case warning  = "Warning"
    case critical = "Critical"
    case swap     = "Swap"

    // Comparable order: normal < elevated < warning < critical < swap
    private var rank: Int {
        switch self {
        case .normal:   return 0
        case .elevated: return 1
        case .warning:  return 2
        case .critical: return 3
        case .swap:     return 4
        }
    }

    static func < (lhs: PressureLevel, rhs: PressureLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    var color: Color {
        switch self {
        case .normal:   return DS.pressureNormal
        case .elevated: return DS.pressureElevated
        case .warning:  return DS.pressureWarning
        case .critical: return DS.pressureCritical
        case .swap:     return DS.pressureSwap
        }
    }

    var label: String { rawValue }
}

// MARK: - MemorySample

struct MemorySample {
    let wiredBytes:      UInt64
    let compressedBytes: UInt64
    let appBytes:        UInt64
    let freeBytes:       UInt64
    let totalBytes:      UInt64
    let swapUsedBytes:   UInt64
    let pressureLevel:   PressureLevel
    let timestamp:       Date

    /// Total used bytes (wired + compressed + app).
    var usedBytes: UInt64 {
        wiredBytes + compressedBytes + appBytes
    }

    /// Used fraction 0–100.
    var usedPercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100.0 : 0.0
    }
}

// MARK: - MemoryMonitor

@MainActor
final class MemoryMonitor: ObservableObject {

    static let shared = MemoryMonitor()

    // ── Published state ──────────────────────────────────────────────────────
    @Published var pressureLevel:        PressureLevel = .normal
    @Published var wiredBytes:           UInt64 = 0
    @Published var compressedBytes:      UInt64 = 0
    @Published var appBytes:             UInt64 = 0
    @Published var freeBytes:            UInt64 = 0
    @Published var totalBytes:           UInt64 = 0
    @Published var swapUsedBytes:        UInt64 = 0
    @Published var pressureHistory:      RollingBuffer<MemorySample> = RollingBuffer(capacity: 900)
    @Published var usageRateMBPerMin:    Double = 0.0
    @Published var minutesUntilCritical: Double? = nil

    /// Peak sample per hour-of-day (0–23), keyed for PressureHeatmapView.
    var peakSamples: [Int: MemorySample] = [:]

    private var cancellables = Set<AnyCancellable>()

    // ── Init — deferral pattern (critical — matches netBee LatencyMonitor) ───
    private init() {
        // Do NOT start the timer here. This init runs inside the dispatch_once
        // block that initialises `shared`. Starting a Timer or calling any
        // MainActor-bound work while that lock is held can cause re-entrant
        // deadlocks. Defer to the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    // MARK: - Timer setup

    private func start() {
        // Immediate first sample so the UI is populated before the first tick.
        sample()

        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.sample() }
            .store(in: &cancellables)
    }

    // MARK: - sample()

    private func sample() {
        // ── 1. host_statistics64 (HOST_VM_INFO64) ───────────────────────────
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard vmResult == KERN_SUCCESS else { return }

        // Use vm_kernel_page_size (matches kernel's page size, may differ from
        // vm_page_size on Apple Silicon).
        let pageSize = UInt64(vm_kernel_page_size)
        let total    = UInt64(ProcessInfo.processInfo.physicalMemory)

        let wired      = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        // App memory = internal pages minus purgeable pages
        let internalPages  = vmStats.internal_page_count
        let purgeablePages = vmStats.purgeable_count
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        let app = UInt64(appPages) * pageSize
        // Free = speculative + free pages
        let free = (UInt64(vmStats.speculative_count) + UInt64(vmStats.free_count)) * pageSize

        // ── 2. sysctl swap usage ─────────────────────────────────────────────
        var xswUsage = xsw_usage()
        var xswLen   = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &xswUsage, &xswLen, nil, 0)
        let swapUsed = xswUsage.xsu_used

        // ── 3. IOKit kernel pressure level ───────────────────────────────────
        let kernelLevel = readKernelPressureLevel()

        // ── 4. Percentage-based pressure level ───────────────────────────────
        let used          = wired + compressed + app
        let usedPct       = total > 0 ? Double(used) / Double(total) * 100.0 : 0.0
        let settings      = MemSnapSettings.shared
        let pctLevel      = pressureLevelFromPercent(
            usedPct,
            elevated: settings.pressureThresholdElevated,
            warning:  settings.pressureThresholdWarning,
            critical: settings.pressureThresholdCritical
        )

        // ── 5. Take the worse of kernel + percentage ──────────────────────────
        var combinedLevel = max(kernelLevel, pctLevel)
        // Swap trumps everything when swap file is active.
        if swapUsed > 0 { combinedLevel = max(combinedLevel, .swap) }

        // ── 6. Build sample ───────────────────────────────────────────────────
        let s = MemorySample(
            wiredBytes:      wired,
            compressedBytes: compressed,
            appBytes:        app,
            freeBytes:       free,
            totalBytes:      total,
            swapUsedBytes:   swapUsed,
            pressureLevel:   combinedLevel,
            timestamp:       Date()
        )

        // ── 7. Append to rolling buffer ───────────────────────────────────────
        pressureHistory.append(s)

        // ── 8. Update peak for current hour ──────────────────────────────────
        let hour = Calendar.current.component(.hour, from: s.timestamp)
        if let existing = peakSamples[hour] {
            if s.usedBytes > existing.usedBytes { peakSamples[hour] = s }
        } else {
            peakSamples[hour] = s
        }

        // ── 9. Compute trend (slope over last 60 samples) ─────────────────────
        let (rate, eta) = computeTrend(
            history:  pressureHistory,
            total:    total,
            current:  combinedLevel,
            critPct:  settings.pressureThresholdCritical
        )
        usageRateMBPerMin    = rate
        minutesUntilCritical = eta

        // ── 10. Publish scalar properties ─────────────────────────────────────
        pressureLevel   = combinedLevel
        wiredBytes      = wired
        compressedBytes = compressed
        appBytes        = app
        freeBytes       = free
        totalBytes      = total
        swapUsedBytes   = swapUsed
    }

    // MARK: - PressureLevel helpers

    /// Map a usage percentage to a PressureLevel using the configured thresholds.
    private func pressureLevelFromPercent(
        _ pct: Double,
        elevated: Double,
        warning: Double,
        critical: Double
    ) -> PressureLevel {
        if pct >= critical  { return .critical  }
        if pct >= warning   { return .warning   }
        if pct >= elevated  { return .elevated  }
        return .normal
    }

    /// Read `kIOResourceMemoryPressureKey` from the IOKit registry and map it to
    /// a `PressureLevel`.
    private func readKernelPressureLevel() -> PressureLevel {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOResourceMatch")
        )
        guard service != IO_OBJECT_NULL else { return .normal }
        defer { IOObjectRelease(service) }

        guard let rawValue = IORegistryEntryCreateCFProperty(
            service,
            "kIOResourceMemoryPressureKey" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else { return .normal }

        // The value is a CFString: "Normal", "Warning", "Critical"
        guard let str = rawValue as? String else { return .normal }
        switch str.lowercased() {
        case "warning":  return .elevated
        case "critical": return .critical
        default:         return .normal
        }
    }

    // MARK: - Trend computation

    /// Returns `(usageRateMBPerMin, minutesUntilCritical?)`.
    ///
    /// Uses a simple linear least-squares slope over `usedBytes` for the last 60
    /// samples (≈ 60 s at 1 Hz). Falls back to a simpler delta when fewer than
    /// two samples are available.
    private func computeTrend(
        history: RollingBuffer<MemorySample>,
        total: UInt64,
        current: PressureLevel,
        critPct: Double
    ) -> (Double, Double?) {
        let window = history.last(60)
        guard window.count >= 2 else { return (0.0, nil) }

        // Linear regression: slope of usedBytes over time (in seconds).
        let n    = Double(window.count)
        let xMid = (n - 1) / 2.0   // indices are 0..(n-1), so centred at mid
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0
        for (i, sample) in window.enumerated() {
            let x = Double(i) - xMid
            let y = Double(sample.usedBytes)
            sumX  += x
            sumY  += y
            sumXY += x * y
            sumXX += x * x
        }
        let denom = n * sumXX - sumX * sumX
        guard abs(denom) > 1e-9 else { return (0.0, nil) }
        let slopeBytesPerSec = (n * sumXY - sumX * sumY) / denom

        // Convert bytes/s → MB/min (1 MB = 1_048_576 bytes; 60 s/min)
        let rateMBPerMin = slopeBytesPerSec / 1_048_576.0 * 60.0

        // minutesUntilCritical: nil if already critical, or rate ≤ 0
        guard current < .critical, rateMBPerMin > 0 else {
            return (rateMBPerMin, nil)
        }
        let criticalBytes = Double(total) * critPct / 100.0
        let usedNow = Double(window.last?.usedBytes ?? 0)
        let headroom = criticalBytes - usedNow
        guard headroom > 0 else { return (rateMBPerMin, nil) }

        let ratePerMin = rateMBPerMin * 1_048_576.0 // back to bytes/min
        let eta = headroom / ratePerMin

        return (rateMBPerMin, eta)
    }
}
