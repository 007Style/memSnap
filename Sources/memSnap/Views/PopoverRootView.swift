import SwiftUI

// MARK: - PopoverRootView

struct PopoverRootView: View {
    @ObservedObject var mem = MemoryMonitor.shared

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 12) {
                // ── Header: title + pressure badge + gear ─────────────────
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(mem.pressureLevel.color)
                            .frame(width: 8, height: 8)
                            .shadow(color: mem.pressureLevel.color.opacity(0.8), radius: 4)

                        Text("memSnap")
                            .font(DS.fontTitle)
                            .foregroundStyle(DS.textPrimary)

                        Text(mem.pressureLevel.label)
                            .font(DS.fontCaption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(mem.pressureLevel.color.opacity(0.18))
                            .foregroundStyle(mem.pressureLevel.color)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        SettingsWindowController.shared.show()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textSecondary)
                            .padding(6)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                .padding(.horizontal, 4)

                // ── Main scrollable content ───────────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        MemoryHeaderView()
                        PressureHistoryView()
                        SwapView()
                        ProcessListView()
                        PressureHeatmapView()
                        ActionFooterView()
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 360)
        .preferredColorScheme(.dark)
    }
}
