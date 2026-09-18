import SwiftUI
import AppKit

// ═══════════════════════════════════════════════════════════════════════════════
// ActionFooterView.swift — Purge, Export CSV, Activity Monitor actions
// ═══════════════════════════════════════════════════════════════════════════════

struct ActionFooterView: View {
    @State private var purgeLabel  = "🧹 Free Cache"
    @State private var exportLabel = "📥 Export CSV"

    var body: some View {
        HStack(spacing: 8) {
            footerButton(label: $purgeLabel) {
                purgeMemoryCache()
            }

            footerButton(label: $exportLabel) {
                exportPressureHistory()
            }

            // Activity Monitor — label is static, no feedback state needed
            Button {
                NSWorkspace.shared.open(
                    URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                )
            } label: {
                Text("↗ Activity Monitor")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(DS.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DS.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Reusable capsule button

    @ViewBuilder
    private func footerButton(label: Binding<String>, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Text(label.wrappedValue)
                .font(DS.fontCaption)
                .foregroundStyle(DS.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(DS.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(DS.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - purgeMemoryCache

    private func purgeMemoryCache() {
        let proc = Process()
        proc.launchPath = "/usr/bin/memory_pressure"
        proc.arguments  = ["-S", "-l", "warn"]

        do {
            try proc.run()
        } catch {
            // Fallback: memory_pressure unavailable — try purge via shell.
            // Note: `purge` requires sudo; the process will fail silently when
            // not elevated, but we still attempt it rather than crashing.
            let fallback = Process()
            fallback.launchPath = "/bin/sh"
            fallback.arguments  = ["-c", "purge"]
            try? fallback.run()
        }

        purgeLabel = "✓ Done"
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { purgeLabel = "🧹 Free Cache" }
        }
    }

    // MARK: - exportPressureHistory

    private func exportPressureHistory() {
        let history = MemoryMonitor.shared.pressureHistory.elements

        let isoFormatter = ISO8601DateFormatter()

        var rows: [String] = [
            "timestamp,level,wired_mb,compressed_mb,app_mb,free_mb,swap_mb"
        ]

        for sample in history {
            let ts          = isoFormatter.string(from: sample.timestamp)
            let level       = sample.pressureLevel.rawValue
            let wiredMB     = String(format: "%.2f", Double(sample.wiredBytes)      / 1_048_576)
            let compMB      = String(format: "%.2f", Double(sample.compressedBytes) / 1_048_576)
            let appMB       = String(format: "%.2f", Double(sample.appBytes)        / 1_048_576)
            let freeMB      = String(format: "%.2f", Double(sample.freeBytes)       / 1_048_576)
            let swapMB      = String(format: "%.2f", Double(sample.swapUsedBytes)   / 1_048_576)
            rows.append("\(ts),\(level),\(wiredMB),\(compMB),\(appMB),\(freeMB),\(swapMB)")
        }

        let csv = rows.joined(separator: "\n")

        guard let desktop = FileManager.default
            .urls(for: .desktopDirectory, in: .userDomainMask).first else { return }

        let datePart: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd-HH-mm"
            return f.string(from: Date())
        }()

        let url = desktop.appendingPathComponent("memSnap-export-\(datePart).csv")

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            exportLabel = "✓ Saved"
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { exportLabel = "📥 Export CSV" }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText     = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle      = .warning
            alert.runModal()
        }
    }
}
