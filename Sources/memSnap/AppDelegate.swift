import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    var trayController: TrayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pure menu-bar app — no dock icon, no main window at launch
        NSApp.setActivationPolicy(.accessory)

        // ── Singleton init sequence ──────────────────────────────────────────
        // Each manager starts its own internal timer via DispatchQueue.main.async
        // so the run-loop is already running when the first tick fires.
        _ = MemoryMonitor.shared
        _ = ProcessMonitor.shared
        _ = NotificationManager.shared
        _ = AutoKillManager.shared

        // TrayController owns the NSStatusItem and the popover.
        trayController = TrayController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
