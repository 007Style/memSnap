import Foundation
import ServiceManagement

// MARK: - Login Item Manager
//
// Strategy:
//   1. Try SMAppService.mainApp (works when running from a signed .app bundle).
//   2. Fall back to a LaunchAgent plist in ~/Library/LaunchAgents — this works
//      for both the raw binary (swift run / build) and unsigned .app bundles.
//
// The checkbox state is persisted in UserDefaults so the menu always reflects
// the real intent even when SMAppService can't query status.

@MainActor
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published private(set) var isEnabled: Bool = false

    private let plistLabel  = App.bundleID
    private let defaultsKey = "\(App.bundleID).startAtLogin"
    private var launchAgentsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(App.bundleID).plist")
    }

    private init() {
        // Restore last-known state
        isEnabled = UserDefaults.standard.bool(forKey: defaultsKey)
        // Sync against reality on launch
        syncState()
    }

    // MARK: - Public

    func toggle() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: defaultsKey)

        // Try SMAppService first (requires proper .app bundle + signed)
        if trySMAppService(enabled: enabled) { return }

        // Fallback: LaunchAgent plist
        if enabled {
            installLaunchAgent()
        } else {
            removeLaunchAgent()
        }
    }

    // MARK: - SMAppService

    @discardableResult
    private func trySMAppService(enabled: Bool) -> Bool {
        // SMAppService only works when running inside a proper .app bundle.
        // Check by seeing if the main bundle has an executable path inside .app
        let execPath = Bundle.main.executablePath ?? ""
        guard execPath.contains(".app/") else { return false }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            print("[memSnap] SMAppService failed (\(error.localizedDescription)), trying LaunchAgent fallback")
            return false
        }
    }

    // MARK: - LaunchAgent fallback

    private var executablePath: String {
        // Use the real running binary path
        Bundle.main.executablePath
            ?? ProcessInfo.processInfo.arguments[0]
    }

    private func installLaunchAgent() {
        let plist: [String: Any] = [
            "Label":           plistLabel,
            "ProgramArguments": [executablePath],
            "RunAtLoad":       true,
            "KeepAlive":       false,
            "StandardOutPath": "/dev/null",
            "StandardErrorPath": "/dev/null"
        ]

        do {
            let dir = launchAgentsURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir,
                withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: launchAgentsURL, options: .atomic)

            // Load it immediately so it takes effect without a logout
            let _ = try? shellOut("launchctl load '\(launchAgentsURL.path)'")
            print("[memSnap] LaunchAgent installed at \(launchAgentsURL.path)")
        } catch {
            print("[memSnap] Failed to install LaunchAgent: \(error)")
        }
    }

    private func removeLaunchAgent() {
        // Unload first, then delete
        let _ = try? shellOut("launchctl unload '\(launchAgentsURL.path)'")
        try? FileManager.default.removeItem(at: launchAgentsURL)
        print("[memSnap] LaunchAgent removed")
    }

    private func syncState() {
        // If the plist exists on disk, that's ground truth
        let agentExists = FileManager.default.fileExists(atPath: launchAgentsURL.path)
        // Also check SMAppService if available
        let smEnabled = (Bundle.main.executablePath?.contains(".app/") == true)
            && SMAppService.mainApp.status == .enabled
        let realEnabled = agentExists || smEnabled
        if realEnabled != isEnabled {
            isEnabled = realEnabled
            UserDefaults.standard.set(realEnabled, forKey: defaultsKey)
        }
    }

    // MARK: - Shell helper

    @discardableResult
    private func shellOut(_ cmd: String) throws -> String {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments  = ["-c", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        task.launch()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                      encoding: .utf8) ?? ""
    }
}
