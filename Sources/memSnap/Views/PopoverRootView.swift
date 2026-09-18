import SwiftUI

// MARK: - PopoverRootView

struct PopoverRootView: View {
    @ObservedObject var mem = MemoryMonitor.shared
    @State var showSettings = false
    @State var showAbout = false

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 12) {
                if showSettings {
                    SettingsView(showSettings: $showSettings)
                } else {
                    // Header section (Title + Gear button)
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
                            showSettings.toggle()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(showSettings ? DS.pressureElevated : DS.textSecondary)
                                .padding(6)
                                .background(showSettings ? DS.surfaceHover : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Settings")
                    }
                    .padding(.horizontal, 4)

                    // Main Popover Content Stack
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            // 1. Memory breakdown bar & metrics
                            MemoryHeaderView()

                            // 2. Pressure history sparkline & time window picker
                            PressureHistoryView()

                            // 3. Swap view (conditionally rendered if swap > 0)
                            SwapView()

                            // 4. Process list with kill/focus/growth tracking
                            ProcessListView()

                            // 5. Hourly pressure heatmap
                            PressureHeatmapView()

                            // 6. Action footer: Purge / Export CSV / Activity Monitor
                            ActionFooterView()
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 360)
        .preferredColorScheme(.dark)
    }
}
