import AppKit
import Darwin
import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// ProcessListView.swift — Top-8 process list with kill / focus / growth badge
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - GrowthBadge

struct GrowthBadge: View {
    let direction: GrowthDirection
    let rateMBPerMin: Double

    private var symbol: String {
        switch direction {
        case .up: return "↑"
        case .down: return "↓"
        case .stable: return "—"
        }
    }

    private var color: Color {
        switch direction {
        case .up: return DS.pressureCritical
        case .down: return DS.pressureNormal
        case .stable: return DS.textMuted
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(symbol)
                .font(DS.fontMono)
                .fontWeight(.bold)

            if direction != .stable {
                Text(String(format: "%.0f MB/m", abs(rateMBPerMin)))
                    .font(DS.fontMono)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 4)
        .padding(.vertical, 1.5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - ProcessRowView

struct ProcessRowView: View {
    let entry: ProcessEntry
    let onFocus: (ProcessEntry) -> Void
    let onKill: (ProcessEntry) -> Void

    private var isSystemProcess: Bool {
        entry.id < 100 || entry.name == "kernel_task"
    }

    private var memoryString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(entry.rssBytes))
    }

    var body: some View {
        HStack(spacing: 8) {
            // App Icon
            if let icon = entry.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(DS.textSecondary)
            }

            // Process Name
            Text(entry.name)
                .font(DS.fontLabel)
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 90, alignment: .leading)

            // Memory
            Text(memoryString)
                .font(DS.fontMono)
                .foregroundStyle(DS.textSecondary)
                .lineLimit(1)

            // Growth Badge
            GrowthBadge(direction: entry.growthDirection, rateMBPerMin: entry.growthMBPerMin)

            // CPU %
            Text(String(format: "%.1f%%", entry.cpuPercent))
                .font(DS.fontMono)
                .foregroundStyle(DS.textMuted)

            Spacer(minLength: 4)

            // Focus button
            Button {
                onFocus(entry)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(DS.surfaceHover)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSystemProcess)
            .help(isSystemProcess ? "System process cannot be focused" : "Focus \(entry.name)")

            // Kill button
            Button {
                onKill(entry)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.pressureCritical)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(DS.pressureCritical.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSystemProcess)
            .help(isSystemProcess ? "System process cannot be killed" : "Kill \(entry.name)")
        }
        .padding(.vertical, 3)
        .opacity(isSystemProcess ? 0.35 : 1.0)
    }
}

// MARK: - ProcessListView

struct ProcessListView: View {
    @ObservedObject var procs = ProcessMonitor.shared

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 10) {
                // Section Header
                SectionHeader("Top Processes", subtitle: "by RSS", color: DS.pressureElevated)

                // Process list
                if procs.topProcesses.isEmpty {
                    Text("Scanning processes…")
                        .font(DS.fontCaption)
                        .foregroundStyle(DS.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 4) {
                        ForEach(procs.topProcesses) { entry in
                            ProcessRowView(
                                entry: entry,
                                onFocus: focusProcess,
                                onKill: killProcess
                            )
                            if entry.id != procs.topProcesses.last?.id {
                                Divider()
                                    .background(DS.border)
                            }
                        }
                    }
                }

                // Footer link
                HStack {
                    Spacer()
                    Button {
                        let appURL = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                        NSWorkspace.shared.open(appURL)
                    } label: {
                        Text("↗ Open Activity Monitor")
                            .font(DS.fontCaption)
                            .foregroundStyle(DS.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Actions

    private func focusProcess(_ entry: ProcessEntry) {
        if let app = NSRunningApplication(processIdentifier: pid_t(entry.id)) {
            let success = app.activate(options: .activateIgnoringOtherApps)
            if !success {
                showAlert(title: "Could not focus \(entry.name)", message: "Unable to bring application to foreground.")
            }
        } else {
            showAlert(title: "Could not focus \(entry.name)", message: "The process is not a foreground application or does not exist.")
        }
    }

    private func killProcess(_ entry: ProcessEntry) {
        if MemSnapSettings.shared.confirmBeforeKill {
            let alert = NSAlert()
            alert.messageText = "Kill \(entry.name)?"
            alert.informativeText = "Are you sure you want to terminate process \(entry.name) (PID: \(entry.id))?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Kill")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                performKill(entry)
            }
        } else {
            performKill(entry)
        }
    }

    private func performKill(_ entry: ProcessEntry) {
        kill(pid_t(entry.id), SIGTERM)
        watchForExit(pid: entry.id, name: entry.name)
    }

    private func watchForExit(pid: Int, name: String) {
        Task {
            var elapsedMS = 0
            while elapsedMS < 3000 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                elapsedMS += 500

                // kill(pid, 0) returns -1 if process does not exist
                if kill(pid_t(pid), 0) != 0 {
                    // Process is gone
                    return
                }
            }

            // Process is still alive after 3 seconds
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Force Quit \(name)?"
                alert.informativeText = "Process did not respond to SIGTERM."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Force Quit")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    kill(pid_t(pid), SIGKILL)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
