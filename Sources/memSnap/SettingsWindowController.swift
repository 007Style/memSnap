import AppKit
import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// SettingsWindowController.swift — Standalone NSWindow host for SettingsView
// Opens as a proper 500×700 window, not squeezed into the popover.
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
final class SettingsWindowController: NSObject {

    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.isReleasedWhenClosed      = false
            win.titlebarAppearsTransparent = true
            win.titleVisibility           = .hidden
            win.backgroundColor           = NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1)
            win.isMovableByWindowBackground = true
            win.minSize = NSSize(width: 460, height: 500)
            win.maxSize = NSSize(width: 700, height: 1200)
            win.title   = "memSnap Settings"
            win.contentView = NSHostingView(rootView: SettingsWindowView())
            win.center()
            self.window = win
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
