import SwiftUI

// MARK: - SwapView

struct SwapView: View {
    @ObservedObject var mem = MemoryMonitor.shared

    var body: some View {
        if mem.swapUsedBytes > 0 {
            MetricCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionHeader("Swap Memory", color: DS.pressureSwap)
                        Spacer()
                        Text("Swap: \(formatMB(mem.swapUsedBytes)) in use")
                            .font(DS.fontCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.pressureSwap)
                    }

                    // Fill bar: proportional to total RAM or used swap representation
                    GeometryReader { geo in
                        let w = geo.size.width
                        // Swap fill proportion relative to total memory (or min bar for visibility)
                        let total = mem.totalBytes > 0 ? Double(mem.totalBytes) : 1.0
                        let proportion = min(max(Double(mem.swapUsedBytes) / total, 0.05), 1.0)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DS.surfaceHover)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DS.pressureSwap)
                                .frame(width: w * CGFloat(proportion), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    private func formatMB(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}
