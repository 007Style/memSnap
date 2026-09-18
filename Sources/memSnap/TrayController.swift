import AppKit
import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// TrayController.swift — NSStatusItem + Icon Rendering + Click Handling
//
// Left-click  → toggle NSPopover (stub content for Sub-Task 5)
// Right-click → context menu
//
// Four icon render paths dispatched by MemSnapSettings.shared.iconStyle:
//   • segmentedBar  — 64×18 stacked horizontal bar (default)
//   • sparkline     — 56×18 pressure history bezier line + fill
//   • arcGauge      — 22×18 semicircle arc, level color
//   • pieChart      — 20×20 4-wedge proportional pie
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - TrayController

@MainActor
final class TrayController: NSObject {

    static var shared: TrayController?

    // ── Owned objects ────────────────────────────────────────────────────────
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var popover:     NSPopover?
    private var cancellables = Set<AnyCancellable>()

    // ── Sparkline history (40 samples of pressure %) ─────────────────────────
    private var sparklineHistory: [Double] = Array(repeating: 0, count: 40)

    // MARK: - Init

    override init() {
        super.init()
        TrayController.shared = self
        setupStatusItem()
        setupPopover()
        startIconUpdates()
        print("[memSnap] TrayController initialised")
    }

    // MARK: - statusItem setup

    private func setupStatusItem() {
        guard let btn = statusItem.button else { return }
        btn.action = #selector(handleClick)
        btn.target = self
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // Render initial icon immediately (zero data)
        renderCurrentIcon()
    }

    // MARK: - Popover setup (stub — real content in Sub-Task 5)

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize  = NSSize(width: 360, height: 400)
        pop.behavior     = .transient
        let hostingController = NSHostingController(rootView: PopoverRootView())
        pop.contentViewController = hostingController
        self.popover = pop
    }

    // MARK: - Click handling

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let pop = popover, let btn = statusItem.button else { return }
        if pop.isShown {
            pop.performClose(nil)
        } else {
            pop.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Called by NotificationManager (Sub-Task 8) to reveal the popover.
    func openPopover() {
        guard let pop = popover, let btn = statusItem.button else { return }
        if !pop.isShown {
            pop.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open memSnap", action: #selector(openMemSnap), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let about = NSMenuItem(title: "About memSnap…", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit memSnap", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        // beeMon/netBee pattern: assign → performClick → clear
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openMemSnap()  { togglePopover() }
    @objc private func showAbout()    { AboutWindowController.shared.show() }
    @objc private func showSettings() { openPopover() }   // Sub-Task 5 will route to SettingsView

    // MARK: - Icon update timer

    private func startIconUpdates() {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.renderCurrentIcon()
            }
            .store(in: &cancellables)
    }

    private func renderCurrentIcon() {
        let mem      = MemoryMonitor.shared
        let settings = MemSnapSettings.shared
        let level    = mem.pressureLevel
        let total    = mem.totalBytes > 0 ? mem.totalBytes : 1
        let wiredF   = Double(mem.wiredBytes)      / Double(total)
        let compF    = Double(mem.compressedBytes) / Double(total)
        let appF     = Double(mem.appBytes)        / Double(total)
        let freeF    = Double(mem.freeBytes)       / Double(total)

        // Update sparkline history
        let pct = mem.pressureHistory.elements.last?.usedPercent ?? 0.0
        sparklineHistory.append(pct)
        if sparklineHistory.count > 40 { sparklineHistory.removeFirst() }

        let icon: NSImage
        switch settings.iconStyle {
        case .segmentedBar:
            icon = makeSegmentedBarIcon(wired: wiredF, compressed: compF, app: appF, free: freeF, level: level)
        case .sparkline:
            icon = makeSparklineIcon(history: sparklineHistory, level: level)
        case .arcGauge:
            let usedPct = mem.pressureHistory.elements.last?.usedPercent ?? 0.0
            icon = makeArcGaugeIcon(percent: usedPct / 100.0, level: level)
        case .pieChart:
            icon = makePieChartIcon(wired: wiredF, compressed: compF, app: appF, free: freeF)
        }

        statusItem.button?.image        = icon
        statusItem.button?.imageScaling = .scaleNone
    }

    // MARK: - ── Icon Render Functions ──────────────────────────────────────────

    // ── 1. Segmented Bar — 64w × 18h ─────────────────────────────────────────
    /// 4 horizontal segments (wired/compressed/app/free) with a 1px pressure-
    /// level colored outline border. Fractions are normalised to fill full width.

    private func makeSegmentedBarIcon(
        wired: Double, compressed: Double, app: Double, free: Double,
        level: PressureLevel
    ) -> NSImage {
        let w = 64, h = 18
        let sz = CGSize(width: w, height: h)

        guard let rep = makeBitmapRep(w: w, h: h) else {
            return NSImage(size: sz)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let totalF = wired + compressed + app + free
        let norm   = totalF > 0 ? totalF : 1.0

        // Region colors (AppKit versions of DS tokens)
        let wiredColor      = NSColor(red: 0.36, green: 0.72, blue: 1.00, alpha: 1.0)
        let compressedColor = NSColor(red: 0.56, green: 0.42, blue: 1.00, alpha: 1.0)
        let appColor        = NSColor(red: 0.96, green: 0.78, blue: 0.26, alpha: 1.0)
        let freeColor       = NSColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 0.80)

        let inset: CGFloat  = 1   // border inset
        let barH: CGFloat   = CGFloat(h) - inset * 2
        let barW: CGFloat   = CGFloat(w) - inset * 2

        // Draw segments left → right
        var xCursor = inset
        let segments: [(CGFloat, NSColor)] = [
            (CGFloat(wired / norm)      * barW, wiredColor),
            (CGFloat(compressed / norm) * barW, compressedColor),
            (CGFloat(app / norm)        * barW, appColor),
            (CGFloat(free / norm)       * barW, freeColor),
        ]
        for (segW, color) in segments {
            if segW < 0.5 { xCursor += segW; continue }
            let rect = NSRect(x: xCursor, y: inset, width: segW, height: barH)
            color.setFill()
            NSBezierPath(rect: rect).fill()
            xCursor += segW
        }

        // 1px border colored by pressure level
        let borderColor = nsColor(for: level)
        borderColor.withAlphaComponent(0.90).setStroke()
        let borderPath = NSBezierPath(roundedRect: NSRect(x: 0.5, y: 0.5,
                                                          width: CGFloat(w) - 1,
                                                          height: CGFloat(h) - 1),
                                      xRadius: 2, yRadius: 2)
        borderPath.lineWidth = 1.0
        borderPath.stroke()

        NSGraphicsContext.restoreGraphicsState()

        return makeImage(from: rep, size: sz)
    }

    // ── 2. Sparkline — 56w × 18h ─────────────────────────────────────────────
    /// Bezier line through pressure % values; level-color fill below the line.
    /// Matches beeMon sparkline style.

    private func makeSparklineIcon(history: [Double], level: PressureLevel) -> NSImage {
        let w = 56, h = 18
        let sz = CGSize(width: w, height: h)

        guard let rep = makeBitmapRep(w: w, h: h) else {
            return NSImage(size: sz)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        // Subtle dark pill background
        NSColor(white: 1, alpha: 0.07).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)),
                     xRadius: 3, yRadius: 3).fill()

        let n = history.count
        guard n > 1 else {
            NSGraphicsContext.restoreGraphicsState()
            return makeImage(from: rep, size: sz)
        }

        let lineColor  = nsColor(for: level)
        let xStep      = CGFloat(w - 4) / CGFloat(n - 1)
        let chartH     = CGFloat(h) - 4

        // Build bezier path for the sparkline
        let linePath = NSBezierPath()
        linePath.lineWidth   = 1.5
        linePath.lineCapStyle  = .round
        linePath.lineJoinStyle = .round

        var points: [NSPoint] = []
        for (i, val) in history.enumerated() {
            let x = 2.0 + CGFloat(i) * xStep
            let y = 2.0 + CGFloat(val / 100.0) * chartH
            points.append(NSPoint(x: x, y: y))
        }

        linePath.move(to: points[0])
        // Catmull-Rom style: use line segments with a slight curve via control points
        for i in 1..<points.count {
            let prev  = points[i - 1]
            let curr  = points[i]
            let cpDx  = (curr.x - prev.x) * 0.5
            let cp1   = NSPoint(x: prev.x + cpDx, y: prev.y)
            let cp2   = NSPoint(x: curr.x - cpDx, y: curr.y)
            linePath.curve(to: curr, controlPoint1: cp1, controlPoint2: cp2)
        }

        // Fill area under the sparkline
        let fillPath = linePath.copy() as! NSBezierPath
        fillPath.line(to: NSPoint(x: points.last!.x, y: 1.0))
        fillPath.line(to: NSPoint(x: points.first!.x, y: 1.0))
        fillPath.close()
        lineColor.withAlphaComponent(0.25).setFill()
        fillPath.fill()

        // Draw the line on top
        lineColor.withAlphaComponent(0.95).setStroke()
        linePath.stroke()

        // Current-value dot at the last point
        let dot = points.last!
        let dotPath = NSBezierPath(ovalIn: NSRect(x: dot.x - 2, y: dot.y - 2, width: 4, height: 4))
        lineColor.setFill()
        dotPath.fill()

        NSGraphicsContext.restoreGraphicsState()
        return makeImage(from: rep, size: sz)
    }

    // ── 3. Arc Gauge — 22w × 18h ─────────────────────────────────────────────
    /// Semicircle (180°) track in dark gray; filled arc in level color showing %.

    private func makeArcGaugeIcon(percent: Double, level: PressureLevel) -> NSImage {
        let w = 22, h = 18
        let sz = CGSize(width: w, height: h)

        guard let rep = makeBitmapRep(w: w, h: h) else {
            return NSImage(size: sz)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let cx: CGFloat   = CGFloat(w) / 2.0
        let cy: CGFloat   = 3.0          // arc baseline
        let radius: CGFloat = 8.5
        let lineW: CGFloat  = 3.0

        // Track arc (dark gray): 180° = start 0° end 180° (AppKit coords: 0 = right, CCW)
        let trackPath = NSBezierPath()
        trackPath.appendArc(
            withCenter: NSPoint(x: cx, y: cy),
            radius: radius,
            startAngle: 0,
            endAngle: 180
        )
        NSColor(white: 0.25, alpha: 1.0).setStroke()
        trackPath.lineWidth   = lineW
        trackPath.lineCapStyle = .round
        trackPath.stroke()

        // Filled arc from 0° to (percent × 180°)
        let endAngle = CGFloat(percent.clamped(to: 0...1)) * 180.0
        if endAngle > 0 {
            let fillPath = NSBezierPath()
            fillPath.appendArc(
                withCenter: NSPoint(x: cx, y: cy),
                radius: radius,
                startAngle: 0,
                endAngle: endAngle
            )
            nsColor(for: level).withAlphaComponent(0.95).setStroke()
            fillPath.lineWidth   = lineW
            fillPath.lineCapStyle = .round
            fillPath.stroke()
        }

        NSGraphicsContext.restoreGraphicsState()
        return makeImage(from: rep, size: sz)
    }

    // ── 4. Pie Chart — 20w × 20h ─────────────────────────────────────────────
    /// 4 proportional wedge arcs in DS region colors.

    private func makePieChartIcon(
        wired: Double, compressed: Double, app: Double, free: Double
    ) -> NSImage {
        let w = 20, h = 20
        let sz = CGSize(width: w, height: h)

        guard let rep = makeBitmapRep(w: w, h: h) else {
            return NSImage(size: sz)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let cx: CGFloat     = CGFloat(w) / 2.0
        let cy: CGFloat     = CGFloat(h) / 2.0
        let radius: CGFloat = 8.5
        let totalF          = wired + compressed + app + free
        let norm            = totalF > 0 ? totalF : 1.0

        let slices: [(Double, NSColor)] = [
            (wired      / norm, NSColor(red: 0.36, green: 0.72, blue: 1.00, alpha: 1.0)),
            (compressed / norm, NSColor(red: 0.56, green: 0.42, blue: 1.00, alpha: 1.0)),
            (app        / norm, NSColor(red: 0.96, green: 0.78, blue: 0.26, alpha: 1.0)),
            (free       / norm, NSColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 0.70)),
        ]

        // Thin separator ring so wedges don't bleed together
        let bgCircle = NSBezierPath(ovalIn: NSRect(x: cx - radius - 0.5, y: cy - radius - 0.5,
                                                   width: (radius + 0.5) * 2,
                                                   height: (radius + 0.5) * 2))
        NSColor(white: 0.0, alpha: 1.0).setFill()
        bgCircle.fill()

        var startDeg: CGFloat = 90   // start from top (12 o'clock)
        for (fraction, color) in slices {
            let sweepDeg = CGFloat(fraction) * 360.0
            if sweepDeg < 0.5 { startDeg += sweepDeg; continue }

            let path = NSBezierPath()
            path.move(to: NSPoint(x: cx, y: cy))
            path.appendArc(
                withCenter: NSPoint(x: cx, y: cy),
                radius: radius,
                startAngle: startDeg,
                endAngle: startDeg + sweepDeg
            )
            path.close()
            color.setFill()
            path.fill()
            startDeg += sweepDeg
        }

        NSGraphicsContext.restoreGraphicsState()
        return makeImage(from: rep, size: sz)
    }

    // MARK: - Drawing helpers

    /// Allocate a concrete RGBA bitmap rep (avoids system tinting on template images).
    private func makeBitmapRep(w: Int, h: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )
    }

    /// Wrap a bitmap rep into an NSImage; set isTemplate = false (mandatory).
    private func makeImage(from rep: NSBitmapImageRep, size: CGSize) -> NSImage {
        let img = NSImage(size: size)
        img.addRepresentation(rep)
        img.isTemplate = false   // AGENTS.md: isTemplate must be false on all tray icons
        return img
    }

    /// Map a PressureLevel to an NSColor.
    private func nsColor(for level: PressureLevel) -> NSColor {
        switch level {
        case .normal:   return NSColor(red: 0.267, green: 0.851, blue: 0.478, alpha: 1.0)
        case .elevated: return NSColor(red: 0.961, green: 0.784, blue: 0.259, alpha: 1.0)
        case .warning:  return NSColor(red: 0.961, green: 0.541, blue: 0.122, alpha: 1.0)
        case .critical: return NSColor(red: 0.941, green: 0.306, blue: 0.306, alpha: 1.0)
        case .swap:     return NSColor(red: 0.616, green: 0.420, blue: 0.961, alpha: 1.0)
        }
    }
}

// MARK: - Double clamped helper

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
