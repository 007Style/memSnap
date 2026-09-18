import SwiftUI

// MARK: - MemoryHeaderView

struct MemoryHeaderView: View {
    @ObservedObject var mem = MemoryMonitor.shared

    var body: some View {
        MetricCard {
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                SectionHeader("Memory Usage", color: mem.pressureLevel.color)

                // 4-segment proportional horizontal bar
                GeometryReader { geo in
                    let total = mem.totalBytes > 0 ? Double(mem.totalBytes) : 1.0
                    let w = geo.size.width

                    let wiredW = CGFloat(Double(mem.wiredBytes) / total) * w
                    let compW  = CGFloat(Double(mem.compressedBytes) / total) * w
                    let appW   = CGFloat(Double(mem.appBytes) / total) * w
                    let freeW  = CGFloat(Double(mem.freeBytes) / total) * w

                    HStack(spacing: 0) {
                        if wiredW > 0 {
                            Rectangle()
                                .fill(DS.memWired)
                                .frame(width: wiredW)
                        }
                        if compW > 0 {
                            Rectangle()
                                .fill(DS.memCompressed)
                                .frame(width: compW)
                        }
                        if appW > 0 {
                            Rectangle()
                                .fill(DS.memApp)
                                .frame(width: appW)
                        }
                        if freeW > 0 {
                            Rectangle()
                                .fill(DS.memFree)
                                .frame(width: freeW)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .frame(height: 12)

                // Label row: "12.4 GB used · 3.6 GB free" + breakdown legend
                HStack {
                    let usedBytes = mem.wiredBytes + mem.compressedBytes + mem.appBytes
                    Text("\(formatGB(usedBytes)) used · \(formatGB(mem.freeBytes)) free")
                        .font(DS.fontLabel)
                        .foregroundStyle(DS.textPrimary)

                    Spacer()

                    Text("\(Int(totalPercent))%")
                        .font(DS.fontMono)
                        .foregroundStyle(mem.pressureLevel.color)
                }

                // Breakdown legend
                HStack(spacing: 8) {
                    legendItem(title: "Wired", bytes: mem.wiredBytes, color: DS.memWired)
                    legendItem(title: "Comp", bytes: mem.compressedBytes, color: DS.memCompressed)
                    legendItem(title: "App", bytes: mem.appBytes, color: DS.memApp)
                    legendItem(title: "Free", bytes: mem.freeBytes, color: DS.memFree)
                }

                Divider().background(DS.border)

                // Trend prediction label
                HStack(spacing: 6) {
                    if let eta = mem.minutesUntilCritical {
                        let mins = max(1, Int(round(eta)))
                        Text("⚠️ ~\(mins) min until critical")
                            .font(DS.fontCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.pressureWarning)
                    } else {
                        Text("✓ Pressure stable")
                            .font(DS.fontCaption)
                            .foregroundStyle(DS.textMuted)
                    }

                    Spacer()

                    if abs(mem.usageRateMBPerMin) >= 1.0 {
                        let sign = mem.usageRateMBPerMin > 0 ? "+" : ""
                        Text(String(format: "%@%.1f MB/min", sign, mem.usageRateMBPerMin))
                            .font(DS.fontMono)
                            .foregroundStyle(DS.textSecondary)
                    }
                }
            }
        }
    }

    private var totalPercent: Double {
        guard mem.totalBytes > 0 else { return 0.0 }
        let used = mem.wiredBytes + mem.compressedBytes + mem.appBytes
        return Double(used) / Double(mem.totalBytes) * 100.0
    }

    private func legendItem(title: String, bytes: UInt64, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(title): \(formatGBShort(bytes))")
                .font(DS.fontCaption)
                .foregroundStyle(DS.textSecondary)
        }
    }

    private func formatGB(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824.0)
    }

    private func formatGBShort(_ bytes: UInt64) -> String {
        String(format: "%.1fG", Double(bytes) / 1_073_741_824.0)
    }
}
