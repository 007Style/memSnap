import Foundation
import SwiftUI

// MARK: - IconStyle

enum IconStyle: String, CaseIterable {
    case segmentedBar = "segmentedBar"
    case sparkline    = "sparkline"
    case arcGauge     = "arcGauge"
    case pieChart     = "pieChart"

    var displayName: String {
        switch self {
        case .segmentedBar: return "Segmented Bar"
        case .sparkline:    return "Sparkline"
        case .arcGauge:     return "Arc Gauge"
        case .pieChart:     return "Pie Chart"
        }
    }
}

// MARK: - MemSnapSettings

/// All user-configurable settings for memSnap, backed by @AppStorage.
/// Full SettingsView UI is implemented in Sub-Task 10.
@MainActor
final class MemSnapSettings: ObservableObject {

    static let shared = MemSnapSettings()

    // ── Display ─────────────────────────────────────────────────────────────
    @AppStorage("iconStyle")
    var iconStyleRaw: String = IconStyle.segmentedBar.rawValue

    var iconStyle: IconStyle {
        get { IconStyle(rawValue: iconStyleRaw) ?? .segmentedBar }
        set { iconStyleRaw = newValue.rawValue }
    }

    // ── History window ───────────────────────────────────────────────────────
    /// Time window (minutes) shown in pressure history sparkline. Allowed: 1, 5, 15.
    @AppStorage("historyWindowMinutes")
    var historyWindowMinutes: Int = 5

    // ── Kill Behaviour ────────────────────────────────────────────────────────
    @AppStorage("confirmBeforeKill")
    var confirmBeforeKill: Bool = true

    // ── Notifications ─────────────────────────────────────────────────────────
    @AppStorage("notifyCritical")
    var notifyCritical: Bool = true

    @AppStorage("notifyRecovery")
    var notifyRecovery: Bool = true

    /// Seconds of sustained critical/swap pressure required before a notification fires.
    @AppStorage("notificationDurationThreshold")
    var notificationDurationThreshold: Int = 10

    // ── Pressure Thresholds (%) ───────────────────────────────────────────────
    /// Percentage of total RAM used that triggers "Elevated" level.
    @AppStorage("pressureThresholdElevated")
    var pressureThresholdElevated: Double = 60.0

    /// Percentage of total RAM used that triggers "Warning" level.
    @AppStorage("pressureThresholdWarning")
    var pressureThresholdWarning: Double = 80.0

    /// Percentage of total RAM used that triggers "Critical" level.
    @AppStorage("pressureThresholdCritical")
    var pressureThresholdCritical: Double = 90.0

    // ── Launch ────────────────────────────────────────────────────────────────
    @AppStorage("launchAtLogin")
    var launchAtLogin: Bool = false

    private init() {}
}
