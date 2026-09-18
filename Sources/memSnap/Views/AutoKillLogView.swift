import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// AutoKillLogView.swift — Scrollable log of recent auto-kill events
// ═══════════════════════════════════════════════════════════════════════════════

struct AutoKillLogView: View {

    @ObservedObject private var manager = AutoKillManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Section header ────────────────────────────────────────────────
            HStack {
                Text("Auto-Kill Log")
                    .font(DS.fontTitle)
                    .foregroundStyle(DS.textPrimary)
                Spacer()
                if !manager.recentEvents.isEmpty {
                    Button("Clear Log") {
                        manager.recentEvents.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textMuted)
                }
            }

            // ── Event list ────────────────────────────────────────────────────
            if manager.recentEvents.isEmpty {
                Text("No auto-kill events yet")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(manager.recentEvents) { event in
                    EventRow(event: event)
                }
            }
        }
        .padding(DS.cardPadding)
        .background(DS.surface)
        .cornerRadius(DS.cornerRadius)
    }
}

// MARK: - EventRow

private struct EventRow: View {
    let event: AutoKillEvent

    var body: some View {
        HStack(spacing: 8) {
            // Relative timestamp
            Text(relativeTimestamp(event.timestamp))
                .font(DS.fontCaption)
                .foregroundStyle(DS.textMuted)
                .frame(width: 72, alignment: .leading)

            // Process name
            Text(event.processName)
                .font(DS.fontLabel)
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)

            Spacer()

            // RSS at kill
            Text("killed at \(String(format: "%.0f", event.rssAtKillMB)) MB")
                .font(DS.fontCaption)
                .foregroundStyle(DS.pressureCritical)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Relative timestamp helper

    private func relativeTimestamp(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        switch seconds {
        case ..<5:
            return "just now"
        case 5..<60:
            return "\(seconds)s ago"
        case 60..<3600:
            let minutes = seconds / 60
            return "\(minutes) min ago"
        case 3600..<86400:
            let hours = seconds / 3600
            return "\(hours) hr ago"
        default:
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
