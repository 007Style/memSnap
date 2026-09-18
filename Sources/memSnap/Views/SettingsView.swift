import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// SettingsView.swift — Settings panel with Display, Alerts, Thresholds, Rules, Launch
// ═══════════════════════════════════════════════════════════════════════════════

struct SettingsView: View {
    @ObservedObject var settings = MemSnapSettings.shared
    @ObservedObject var loginItem = LoginItemManager.shared
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: DS.spacing) {
            // ── Header with Back Button ───────────────────────────────────────
            HStack {
                Button {
                    showSettings = false
                } label: {
                    HStack(spacing: 4) {
                        Text("← Back")
                            .font(DS.fontLabel)
                            .foregroundStyle(DS.pressureElevated)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Settings")
                    .font(DS.fontTitle)
                    .foregroundStyle(DS.textPrimary)

                Spacer()

                // Spacer to balance the Back button visual weight
                Color.clear
                    .frame(width: 48, height: 1)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            // ── Scrollable Form content ───────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.spacing) {

                    // ── Display Section ──────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Display", color: DS.memWired)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Icon Style")
                                .font(DS.fontCaption)
                                .foregroundStyle(DS.textSecondary)

                            Picker("", selection: Binding<IconStyle>(
                                get: { settings.iconStyle },
                                set: { settings.iconStyle = $0 }
                            )) {
                                ForEach(IconStyle.allCases, id: \.self) { style in
                                    Text("\(style.previewSymbol) \(style.displayName)")
                                        .tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                    .padding(DS.cardPadding)
                    .background(DS.surface)
                    .cornerRadius(DS.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .stroke(DS.border, lineWidth: 1)
                    )

                    // ── Notifications Section ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Notifications", color: DS.pressureWarning)

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Critical pressure alert", isOn: $settings.notifyCritical)
                                .toggleStyle(.switch)
                                .font(DS.fontLabel)
                                .foregroundStyle(DS.textPrimary)

                            Toggle("Recovery alert", isOn: $settings.notifyRecovery)
                                .toggleStyle(.switch)
                                .font(DS.fontLabel)
                                .foregroundStyle(DS.textPrimary)

                            Divider()
                                .background(DS.border)
                                .padding(.vertical, 2)

                            HStack {
                                Text("Alert after \(settings.notificationDurationThreshold)s at critical")
                                    .font(DS.fontLabel)
                                    .foregroundStyle(DS.textPrimary)
                                Spacer()
                                Stepper("", value: $settings.notificationDurationThreshold, in: 0...60, step: 5)
                                    .labelsHidden()
                            }
                        }
                    }
                    .padding(DS.cardPadding)
                    .background(DS.surface)
                    .cornerRadius(DS.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .stroke(DS.border, lineWidth: 1)
                    )

                    // ── Kill Behavior Section ────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Kill Behavior", color: DS.pressureCritical)

                        Toggle("Confirm before killing process", isOn: $settings.confirmBeforeKill)
                            .toggleStyle(.switch)
                            .font(DS.fontLabel)
                            .foregroundStyle(DS.textPrimary)
                    }
                    .padding(DS.cardPadding)
                    .background(DS.surface)
                    .cornerRadius(DS.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .stroke(DS.border, lineWidth: 1)
                    )

                    // ── Pressure Thresholds Section ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Pressure Thresholds", color: DS.pressureElevated)

                        // Elevated Threshold
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(DS.pressureElevated)
                                    .frame(width: 6, height: 6)
                                Text("Elevated at \(Int(settings.pressureThresholdElevated))%")
                                    .font(DS.fontLabel)
                                    .foregroundStyle(DS.textPrimary)
                            }
                            Slider(value: $settings.pressureThresholdElevated, in: 40...70, step: 5)
                                .tint(DS.pressureElevated)
                        }

                        // Warning Threshold
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(DS.pressureWarning)
                                    .frame(width: 6, height: 6)
                                Text("Warning at \(Int(settings.pressureThresholdWarning))%")
                                    .font(DS.fontLabel)
                                    .foregroundStyle(DS.textPrimary)
                            }
                            Slider(value: $settings.pressureThresholdWarning, in: 60...85, step: 5)
                                .tint(DS.pressureWarning)
                        }

                        // Critical Threshold
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(DS.pressureCritical)
                                    .frame(width: 6, height: 6)
                                Text("Critical at \(Int(settings.pressureThresholdCritical))%")
                                    .font(DS.fontLabel)
                                    .foregroundStyle(DS.textPrimary)
                            }
                            Slider(value: $settings.pressureThresholdCritical, in: 75...95, step: 5)
                                .tint(DS.pressureCritical)
                        }
                    }
                    .padding(DS.cardPadding)
                    .background(DS.surface)
                    .cornerRadius(DS.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .stroke(DS.border, lineWidth: 1)
                    )

                    // ── Auto-Kill Rules & Logs Section ───────────────────────────────
                    AutoKillRulesView()

                    AutoKillLogView()

                    // ── Launch Section ───────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Launch", color: DS.pressureSwap)

                        Toggle("Launch at Login", isOn: Binding<Bool>(
                            get: { loginItem.isEnabled },
                            set: { loginItem.setEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .font(DS.fontLabel)
                        .foregroundStyle(DS.textPrimary)
                    }
                    .padding(DS.cardPadding)
                    .background(DS.surface)
                    .cornerRadius(DS.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .stroke(DS.border, lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - IconStyle Extensions for Preview Symbol

extension IconStyle {
    var previewSymbol: String {
        switch self {
        case .segmentedBar: return "▬"
        case .sparkline:    return "📈"
        case .arcGauge:     return "◔"
        case .pieChart:     return "◕"
        }
    }
}
