import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// PressureHeatmapView.swift — 24-hour hourly pressure heatmap
// ═══════════════════════════════════════════════════════════════════════════════

struct PressureHeatmapView: View {
    @ObservedObject var mem = MemoryMonitor.shared
    @State private var pulseScale: CGFloat = 1.0

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    // Labels shown only at hours 0, 6, 12, 18
    private let labeledHours = Set([0, 6, 12, 18])

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Today's Pressure (Hourly Peak)")

                HStack(spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        hourSquare(hour: hour)
                    }
                }

                // Hour axis labels: show only 0, 6, 12, 18
                HStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        Group {
                            if labeledHours.contains(hour) {
                                Text("\(hour)")
                                    .font(DS.fontCaption)
                                    .foregroundStyle(DS.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(width: 10) // 8px square + 2px spacing
                    }
                }
            }
        }
        .onAppear { startPulse() }
    }

    // MARK: - Hour Square

    @ViewBuilder
    private func hourSquare(hour: Int) -> some View {
        let isCurrentHour = (hour == currentHour)
        let fillColor = mem.peakSamples[hour]?.pressureLevel.color ?? DS.surface

        RoundedRectangle(cornerRadius: 2)
            .fill(fillColor.opacity(mem.peakSamples[hour] != nil ? 0.85 : 1.0))
            .frame(width: 8, height: 14)
            .overlay(
                Group {
                    if isCurrentHour {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white, lineWidth: 1)
                    }
                }
            )
            .scaleEffect(isCurrentHour ? pulseScale : 1.0)
            .animation(
                isCurrentHour
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: pulseScale
            )
    }

    // MARK: - Pulse animation

    private func startPulse() {
        pulseScale = 1.05
    }
}
