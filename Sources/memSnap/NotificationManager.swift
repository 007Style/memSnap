import Foundation
import UserNotifications
import Combine
import AppKit

// ═══════════════════════════════════════════════════════════════════════════════
// NotificationManager.swift — Smart alerts with action buttons & debouncing
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    // ── State tracking ───────────────────────────────────────────────────────
    private var previousLevel: PressureLevel = .normal
    private var elevatedSince: Date? = nil
    private var pendingNotificationTask: Task<Void, Never>? = nil

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override private init() {
        super.init()
        setupNotificationCategories()
        UNUserNotificationCenter.current().delegate = self
        requestPermission()
        setupSubscription()
        print("[memSnap] NotificationManager initialised")
    }

    // MARK: - Permission

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            UserDefaults.standard.set(granted, forKey: "memSnap.notificationsGranted")
            if let error = error {
                print("[memSnap] Notification authorization error: \(error.localizedDescription)")
            } else {
                print("[memSnap] Notification authorization granted: \(granted)")
            }
        }
    }

    // MARK: - Category & Action Registration

    private func setupNotificationCategories() {
        let showTopAction = UNNotificationAction(
            identifier: "SHOW_TOP",
            title: "Show Top Process",
            options: .foreground
        )

        let criticalCategory = UNNotificationCategory(
            identifier: "MEMSNAP_CRITICAL",
            actions: [showTopAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([criticalCategory])
    }

    // MARK: - Subscription & Debounce Logic

    private func setupSubscription() {
        MemoryMonitor.shared.$pressureLevel
            .removeDuplicates()
            .sink { [weak self] newLevel in
                self?.handlePressureLevelChange(to: newLevel)
            }
            .store(in: &cancellables)
    }

    private func handlePressureLevelChange(to newLevel: PressureLevel) {
        let oldLevel = previousLevel
        previousLevel = newLevel

        let isNowCriticalOrSwap = (newLevel == .critical || newLevel == .swap)
        let wasCriticalOrSwap = (oldLevel == .critical || oldLevel == .swap)
        let wasElevated = (oldLevel != .normal)

        if isNowCriticalOrSwap && !wasCriticalOrSwap {
            // Entered critical/swap state
            elevatedSince = Date()
            scheduleCriticalNotificationCheck()
        } else if !isNowCriticalOrSwap && wasCriticalOrSwap {
            // Left critical/swap state
            cancelPendingCriticalNotification()
        }

        if newLevel == .normal && wasElevated {
            // Returned to normal from any elevated/warning/critical/swap state
            cancelPendingCriticalNotification()
            elevatedSince = nil
            if MemSnapSettings.shared.notifyRecovery {
                sendRecoveryNotification()
            }
        }
    }

    private func scheduleCriticalNotificationCheck() {
        cancelPendingCriticalNotification()

        let thresholdSeconds = MemSnapSettings.shared.notificationDurationThreshold
        let thresholdNs = UInt64(max(0, thresholdSeconds)) * 1_000_000_000

        pendingNotificationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: thresholdNs)
            guard !Task.isCancelled else { return }

            guard let self = self else { return }
            let currentLevel = MemoryMonitor.shared.pressureLevel
            if (currentLevel == .critical || currentLevel == .swap) && MemSnapSettings.shared.notifyCritical {
                self.sendCriticalNotification()
            }
        }
    }

    private func cancelPendingCriticalNotification() {
        pendingNotificationTask?.cancel()
        pendingNotificationTask = nil
    }

    // MARK: - Notification Delivery

    private func sendCriticalNotification() {
        let mem = MemoryMonitor.shared
        let usedBytes = mem.wiredBytes + mem.compressedBytes + mem.appBytes
        let totalBytes = mem.totalBytes > 0 ? mem.totalBytes : 1

        let usedGB = String(format: "%.1f", Double(usedBytes) / 1_073_741_824.0)
        let pct = Int(Double(usedBytes) / Double(totalBytes) * 100.0)

        let top = ProcessMonitor.shared.topProcesses.first
        let topProcessName = top?.name ?? "Unknown"
        let topProcessGB = String(format: "%.1f", Double(top?.rssBytes ?? 0) / 1_073_741_824.0)

        let content = UNMutableNotificationContent()
        content.title = "⚠️ Memory Pressure Critical"
        content.body = "\(usedGB) GB used (\(pct)%) — Top process: \(topProcessName) using \(topProcessGB) GB"
        content.categoryIdentifier = "MEMSNAP_CRITICAL"
        content.sound = .default

        let center = UNUserNotificationCenter.current()
        let identifier = "memsnap.critical"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                print("[memSnap] Failed to deliver critical notification: \(error.localizedDescription)")
            }
        }
    }

    private func sendRecoveryNotification() {
        let mem = MemoryMonitor.shared
        let freeGB = String(format: "%.1f", Double(mem.freeBytes) / 1_073_741_824.0)

        let content = UNMutableNotificationContent()
        content.title = "✅ Memory Pressure Normal"
        content.body = "Pressure returned to normal. \(freeGB) GB now available."
        content.sound = .default

        let center = UNUserNotificationCenter.current()
        let identifier = "memsnap.recovery"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                print("[memSnap] Failed to deliver recovery notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 14.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        if actionIdentifier == "SHOW_TOP" || actionIdentifier == UNNotificationDefaultActionIdentifier {
            Task { @MainActor in
                TrayController.shared?.openPopover()
            }
        }
        completionHandler()
    }
}
