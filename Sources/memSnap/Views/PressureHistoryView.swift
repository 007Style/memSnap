import SwiftUI

// MARK: - TimeWindow

enum TimeWindow: Int, CaseIterable {
    case oneMinute     = 60
    case fiveMinutes   = 300
    case fifteenMinutes = 900

    var label: String {
        switch self {
        case .oneMinute:      return "1m"
        case .fiveMinutes:    return "5m"
        case .fifteenMinutes: return "15m"
        }
    }
}

// MARK: - TimeWindowPicker

struct TimeWindowPicker: View {
    @Binding var selected: TimeWindow

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimeWindow.allCases, id: \.self) { window in
                Button(window.label) {
                    selected = window
                }
                .font(DS.fontCaption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(selected == window ? DS.pressureElevated.opacity(0.22) : Color.clear)
                .foregroundColor(selected == window ? DS.pressureElevated : DS.textSecondary)
                .cornerRadius(5)
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - PressureHistoryView

struct PressureHistoryView: View {
    @ObservedObject var mem = MemoryMonitor.shared
    @State private var selectedWindow: TimeWindow = .fiveMinutes

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header with title and time window picker
                HStack {
                    SectionHeader("Pressure History", color: mem.pressureLevel.color)
                    Spacer()
                    TimeWindowPicker(selected: $selectedWindow)
                }

                // Sparkline canvas with threshold lines and gradient fill
                Canvas { context, size in
                    let samples = mem.pressureHistory.last(selectedWindow.rawValue)
                    let w = size.width
                    let h = size.height

                    // 1. Draw 3 horizontal dashed threshold lines at 60%, 80%, 90% of height from bottom
                    let thresholds: [CGFloat] = [0.60, 0.80, 0.90]
                    for t in thresholds {
                        let y = h * (1.0 - t)
                        var dashedPath = Path()
                        dashedPath.move(to: CGPoint(x: 0, y: y))
                        dashedPath.addLine(to: CGPoint(x: w, y: y))
                        context.stroke(
                            dashedPath,
                            with: .color(Color.white.opacity(0.12)),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    }

                    guard samples.count > 1 else { return }

                    // Compute points for sparkline
                    let count = samples.count
                    let step = w / CGFloat(count - 1)
                    var points: [CGPoint] = []

                    for (i, sample) in samples.enumerated() {
                        let x = CGFloat(i) * step
                        let fraction = CGFloat(min(max(sample.usedPercent / 100.0, 0.0), 1.0))
                        let y = h * (1.0 - fraction)
                        points.append(CGPoint(x: x, y: y))
                    }

                    // Build line path
                    var linePath = Path()
                    linePath.move(to: points[0])
                    for i in 1..<points.count {
                        linePath.addLine(to: points[i])
                    }

                    // Build area fill path
                    var fillPath = linePath
                    fillPath.addLine(to: CGPoint(x: points.last!.x, y: h))
                    fillPath.addLine(to: CGPoint(x: points.first!.x, y: h))
                    fillPath.closeSubpath()

                    // Gradient fill from pressureLevel.color @ 70% opacity at top of canvas to 0% at bottom
                    let gradient = Gradient(stops: [
                        .init(color: mem.pressureLevel.color.opacity(0.70), location: 0.0),
                        .init(color: mem.pressureLevel.color.opacity(0.0), location: 1.0)
                    ])
                    context.fill(
                        fillPath,
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: h)
                        )
                    )

                    // Stroke line
                    context.stroke(
                        linePath,
                        with: .color(mem.pressureLevel.color.opacity(0.95)),
                        lineWidth: 1.5
                    )
                }
                .frame(height: 70)
            }
        }
    }
}
