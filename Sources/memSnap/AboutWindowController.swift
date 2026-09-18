import AppKit
import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// AboutWindowController.swift — Singleton NSWindow host for AboutView
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
final class AboutWindowController: NSObject {

    static let shared = AboutWindowController()

    private var window: NSWindow?

    // MARK: - show()

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            w.center()
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 610),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed     = false
        win.titlebarAppearsTransparent = true
        win.titleVisibility          = .hidden
        win.backgroundColor          = NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1)
        win.isMovableByWindowBackground = true
        win.contentView              = NSHostingView(rootView: AboutView())
        win.center()
        self.window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
