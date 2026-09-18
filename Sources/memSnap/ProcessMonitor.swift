import AppKit
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// ProcessMonitor.swift — 2 Hz top-8 RSS sampler with growth tracking
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - GrowthDirection

/// Direction of per-process RSS change over a ~30 s window.
/// Stable = absolute rate < 5 MB/min.
enum GrowthDirection {
    case up, down, stable
}

// MARK: - ProcessEntry

struct ProcessEntry: Identifiable {
    let id:              Int          // PID
    let name:            String
    let bundleID:        String?
    let icon:            NSImage?
    let rssBytes:        UInt64
    let cpuPercent:      Double
    let growthMBPerMin:  Double
    let growthDirection: GrowthDirection
}

// MARK: - ProcessMonitor

@MainActor
final class ProcessMonitor: ObservableObject {

    static let shared = ProcessMonitor()

    // ── Published state ──────────────────────────────────────────────────────
    @Published var topProcesses: [ProcessEntry] = []

    // ── Private state ────────────────────────────────────────────────────────

    /// RSS history per PID; each entry is a raw RSS value in bytes.
    /// Capped at 15 entries (= 30 s at 2 Hz).
    private var rssHistory: [Int: [UInt64]] = [:]

    /// Icon cache keyed by bundle ID so we resolve each app only once.
    private var iconCache: [String: NSImage] = [:]

    private var cancellables = Set<AnyCancellable>()

    // ── Init — deferral pattern (matches MemoryMonitor / netBee LatencyMonitor)
    private init() {
        // Do NOT start the timer here. init() runs inside the dispatch_once
        // block that initialises `shared`. Starting a Timer or performing
        // MainActor-bound work while that lock is held can cause re-entrant
        // deadlocks. Defer one run-loop turn.
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    // MARK: - Timer setup

    private func start() {
        // Immediate first sample so the UI has data before the first tick.
        tick()

        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)
    }

    // MARK: - tick()

    private func tick() {
        // Fetch on a background thread; then merge results back on MainActor.
        Task.detached(priority: .utility) {
            let raw = ProcessMonitor.fetchRaw()
            await MainActor.run { [weak self] in
                self?.merge(raw)
            }
        }
    }

    // MARK: - merge(_:)

    /// Called on the main actor. Updates `rssHistory`, resolves icons, builds
    /// `ProcessEntry` values, then publishes to `topProcesses`.
    private func merge(_ raw: [(pid: Int, name: String, rssBytes: UInt64, cpuPercent: Double)]) {
        // ── Sort by RSS, keep top 8 ───────────────────────────────────────────
        let top8 = raw.sorted { $0.rssBytes > $1.rssBytes }.prefix(8)

        // ── Update RSS history ────────────────────────────────────────────────
        var seen = Set<Int>()
        for entry in top8 {
            seen.insert(entry.pid)
            var hist = rssHistory[entry.pid] ?? []
            hist.append(entry.rssBytes)
            if hist.count > 15 { hist.removeFirst() }
            rssHistory[entry.pid] = hist
        }
        // Prune history for PIDs that are no longer in the top 8 to avoid
        // unbounded growth (daemons that fall off the list).
        rssHistory = rssHistory.filter { seen.contains($0.key) }

        // ── Build ProcessEntry values ─────────────────────────────────────────
        var entries: [ProcessEntry] = []
        for item in top8 {
            let (rate, dir) = growthRate(for: item.pid)
            let (bundleID, icon) = resolveApp(pid: item.pid, name: item.name)
            entries.append(ProcessEntry(
                id:              item.pid,
                name:            item.name,
                bundleID:        bundleID,
                icon:            icon,
                rssBytes:        item.rssBytes,
                cpuPercent:      item.cpuPercent,
                growthMBPerMin:  rate,
                growthDirection: dir
            ))
        }

        topProcesses = entries
    }

    // MARK: - Growth rate computation

    /// Returns `(growthMBPerMin, GrowthDirection)` for a PID.
    /// Uses the oldest and newest entries in `rssHistory` over the ~30 s window.
    private func growthRate(for pid: Int) -> (Double, GrowthDirection) {
        guard let hist = rssHistory[pid], hist.count >= 2 else {
            return (0.0, .stable)
        }
        let oldest = hist.first!
        let newest = hist.last!

        // Window duration ≈ (count - 1) × 0.5 s
        let windowSeconds = Double(hist.count - 1) * 0.5
        guard windowSeconds > 0 else { return (0.0, .stable) }

        let deltaMB     = Double(Int64(bitPattern: newest) - Int64(bitPattern: oldest)) / 1_048_576.0
        let rateMBPerMin = deltaMB / windowSeconds * 60.0

        let stableThreshold = 5.0 // MB/min
        let direction: GrowthDirection
        if rateMBPerMin > stableThreshold {
            direction = .up
        } else if rateMBPerMin < -stableThreshold {
            direction = .down
        } else {
            direction = .stable
        }

        return (rateMBPerMin, direction)
    }

    // MARK: - Icon resolution

    /// Resolves bundle ID and icon for a PID, using `NSRunningApplication` when
    /// available and falling back to `NSWorkspace` for daemons.
    private func resolveApp(pid: Int, name: String) -> (String?, NSImage?) {
        // ── Attempt NSRunningApplication lookup ───────────────────────────────
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            let bid = app.bundleIdentifier

            // Return cached icon if available.
            if let bid = bid, let cached = iconCache[bid] {
                return (bid, cached)
            }

            // NSRunningApplication.icon is already the correct app icon.
            if let icon = app.icon {
                if let bid = bid { iconCache[bid] = icon }
                return (bid, icon)
            }

            // If the app object has no icon but has a bundle URL, ask NSWorkspace.
            if let url = app.bundleURL {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 20, height: 20)
                if let bid = bid { iconCache[bid] = icon }
                return (bid, icon)
            }
        }

        // ── Daemon / system process fallback ──────────────────────────────────
        // Check known macOS daemon locations in order of preference.
        let searchPaths: [String] = [
            "/usr/sbin/\(name)",
            "/usr/bin/\(name)",
            "/sbin/\(name)",
            "/bin/\(name)",
            "/System/Library/Frameworks/\(name).framework"
        ]
        for path in searchPaths where FileManager.default.fileExists(atPath: path) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 20, height: 20)
            return (nil, icon)
        }

        // Last resort: generic executable icon.
        let genericIcon = NSWorkspace.shared.icon(forFile: "/usr/bin/true")
        genericIcon.size = NSSize(width: 20, height: 20)
        return (nil, genericIcon)
    }
}

// MARK: - nonisolated static fetchRaw()

extension ProcessMonitor {

    /// Runs `/bin/ps -Arco pid,rss,pcpu,comm` synchronously and returns the
    /// parsed rows as value-type tuples.  Must not be called on the main thread.
    nonisolated static func fetchRaw()
        -> [(pid: Int, name: String, rssBytes: UInt64, cpuPercent: Double)]
    {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments  = ["-Arco", "pid,rss,pcpu,comm"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()   // silence ps stderr

        task.launch()
        task.waitUntilExit()

        let raw = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        var results: [(pid: Int, name: String, rssBytes: UInt64, cpuPercent: Double)] = []

        for line in raw.components(separatedBy: "\n").dropFirst() {   // skip header
            let parts = line
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard parts.count >= 4,
                  let pid   = Int(parts[0]),
                  let rssKB = UInt64(parts[1]),
                  let cpu   = Double(parts[2])
            else { continue }

            let name     = parts[3...].joined(separator: " ")
            let rssBytes = rssKB * 1024

            results.append((pid: pid, name: name, rssBytes: rssBytes, cpuPercent: cpu))
        }

        return results
    }
}
