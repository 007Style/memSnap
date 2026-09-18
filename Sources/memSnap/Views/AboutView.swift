import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// AboutView.swift — 760×580 animated About window
//
// Layout (top → bottom):
//   ┌────────────────────────────────────────────────┐
//   │   Hero strip ~220h: HexGrid + ParticleNetwork  │
//   ├───────────────────┬────────────────────────────┤
//   │  Logo col ~200h   │  Feature pills grid        │
//   ├───────────────────┴────────────────────────────┤
//   │  Live data strip ~120h                         │
//   └────────────────────────────────────────────────┘
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - AboutView

struct AboutView: View {
    @State private var hexPhase: Double = 0

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Hero strip ─────────────────────────────────────────────
                ZStack {
                    HexGridBackground(phase: hexPhase)
                        .opacity(0.06)
                        .ignoresSafeArea()
                    ParticleNetworkCanvas()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()

                Rectangle().fill(DS.border).frame(height: 1)

                // ── Info row ───────────────────────────────────────────────
                HStack(alignment: .top, spacing: 0) {

                    // Left — logo + version + badge
                    VStack(spacing: 8) {
                        Spacer()
                        PulsingRingView()
                        Text("memSnap")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(DS.textPrimary)
                        VersionRow()
                        PressureLevelBadge()
                        Spacer()
                    }
                    .frame(width: 200)
                    .padding(.vertical, 14)

                    Rectangle().fill(DS.border).frame(width: 1).padding(.vertical, 10)

                    // Right — feature pills
                    FeaturePillsGrid()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .background(DS.surface.opacity(0.5))

                Rectangle().fill(DS.border).frame(height: 1)

                // ── Live data strip ────────────────────────────────────────
                HStack(spacing: 0) {
                    LiveSparklineCard()
                    Rectangle().fill(DS.border).frame(width: 1).padding(.vertical, 8)
                    LiveDonutCard()
                    Rectangle().fill(DS.border).frame(width: 1).padding(.vertical, 8)
                    SystemInfoCard()
                }
                .frame(height: 140)
                .background(DS.bg)

                Rectangle().fill(DS.border).frame(height: 1)

                // ── Tagline footer — full width ────────────────────────────
                TaglineRow()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DS.surface.opacity(0.3))
            }
        }
        .frame(width: 760, height: 610)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                hexPhase = 1.0
            }
        }
    }
}

// MARK: - A. HexGridBackground (ported from beeMon)

struct HexGridBackground: View {
    var phase: Double   // 0…1 drives subtle drift

    var body: some View {
        Canvas { context, size in
            let r: CGFloat = 18
            let w = r * 2
            let h = r * sqrt(3)
            let cols = Int(size.width  / w) + 3
            let rows = Int(size.height / h) + 3

            let offsetX = CGFloat(phase) * w
            let offsetY = CGFloat(phase) * h * 0.5

            for row in -1..<rows {
                for col in -1..<cols {
                    let xBase = CGFloat(col) * w * 1.5 - offsetX
                    let yBase = CGFloat(row) * h - offsetY + (col % 2 == 0 ? 0 : h / 2)
                    let center = CGPoint(x: xBase, y: yBase)
                    var path = Path()
                    for i in 0..<6 {
                        let angle = CGFloat(i) * .pi / 3 - .pi / 6
                        let pt = CGPoint(
                            x: center.x + r * cos(angle),
                            y: center.y + r * sin(angle)
                        )
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(Color.white), lineWidth: 0.4)
                }
            }
        }
        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: phase)
    }
}

// MARK: - B. ParticleNetworkCanvas (RAM-themed, adapted from netBee StarNetworkCanvas)

private struct ParticleNetworkCanvas: View {

    @State private var phase:    CGFloat = 0
    @State private var hexPhase: CGFloat = 0

    private let animTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    private let hexTimer  = Timer.publish(every: 0.05,     on: .main, in: .common).autoconnect()

    // 10 RAM-themed nodes: (label, angleOffset, orbitR, size, speed)
    private let nodes: [(label: String, ao: CGFloat, orbitR: CGFloat, size: CGFloat, speed: CGFloat)] = [
        ("RAM",   0.00, 0.30, 4.5, 0.40),
        ("HEAP",  0.62, 0.20, 3.0, 0.65),
        ("WIRED", 1.26, 0.38, 5.5, 0.28),
        ("CACHE", 1.88, 0.15, 2.5, 0.80),
        ("SWAP",  2.51, 0.35, 4.0, 0.33),
        ("APP",   3.14, 0.24, 3.5, 0.55),
        ("FREE",  3.77, 0.40, 6.0, 0.22),
        ("KERN",  4.40, 0.18, 2.0, 0.80),
        ("DISK",  5.03, 0.28, 4.0, 0.45),
        ("VRAM",  5.66, 0.12, 2.5, 1.00),
    ]

    // Color palette for nodes — cycles through pressure level colors
    private let nodeColors: [Color] = [
        DS.pressureNormal, DS.memWired, DS.pressureElevated, DS.memCompressed,
        DS.pressureSwap,   DS.memApp,   DS.pressureNormal,   DS.memWired,
        DS.pressureWarning, DS.pressureCritical,
    ]

    var body: some View {
        Canvas { ctx, size in
            let pos = nodePositions(size: size)
            drawEdges(ctx: ctx, positions: pos, size: size)
            drawNodes(ctx: ctx, positions: pos)
        }
        .background(DS.bg.opacity(0.8))
        .onReceive(animTimer) { _ in phase    += 0.008 }
        .onReceive(hexTimer)  { _ in hexPhase += 0.04  }
    }

    private func nodePositions(size: CGSize) -> [CGPoint] {
        let cx = size.width / 2
        let cy = size.height / 2
        let r  = min(size.width, size.height) / 2
        return nodes.map { n in
            CGPoint(
                x: cx + cos(n.ao + phase * n.speed) * r * n.orbitR,
                y: cy + sin(n.ao + phase * n.speed) * r * n.orbitR * 0.65
            )
        }
    }

    private func drawEdges(ctx: GraphicsContext, positions: [CGPoint], size: CGSize) {
        for i in 0..<positions.count {
            for j in (i+1)..<positions.count {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let d  = sqrt(dx*dx + dy*dy)
                guard d < 200 else { continue }
                var p = Path()
                p.move(to: positions[i])
                p.addLine(to: positions[j])
                let opacity = Double(1 - d / 200) * 0.35
                ctx.stroke(p, with: .color(DS.memWired.opacity(opacity)), lineWidth: 0.8)
            }
        }
    }

    private func drawNodes(ctx: GraphicsContext, positions: [CGPoint]) {
        for (i, pos) in positions.enumerated() {
            let baseR  = nodes[i].size / 2
            let pulse  = 0.6 + 0.4 * sin(phase * 2.0 + CGFloat(i))
            let r      = baseR * pulse
            let color  = nodeColors[i % nodeColors.count]

            // Glow halo
            ctx.fill(
                Path(ellipseIn: .init(x: pos.x - r*3, y: pos.y - r*3, width: r*6, height: r*6)),
                with: .color(color.opacity(0.07 * pulse))
            )
            // Filled node dot
            ctx.fill(
                Path(ellipseIn: .init(x: pos.x - r, y: pos.y - r, width: r*2, height: r*2)),
                with: .color(color.opacity(0.85 * pulse))
            )
            // Label (8pt monospace)
            ctx.draw(
                Text(nodes[i].label)
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(color.opacity(0.70)),
                at: CGPoint(x: pos.x, y: pos.y + r + 7),
                anchor: .center
            )
        }
    }
}

// MARK: - C. PulsingRingView

private struct PulsingRingView: View {
    @State private var ringScale:   Double = 1.0
    @State private var ringOpacity: Double = 0.7

    var body: some View {
        ZStack {
            // Pulsing outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [DS.memWired.opacity(0.6), DS.pressureSwap.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 80, height: 80)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
                .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: ringScale)

            // Inner filled circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DS.memWired.opacity(0.22), DS.pressureSwap.opacity(0.15), DS.bg],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(DS.memWired.opacity(0.25), lineWidth: 1))

            Text("🧠")
                .font(.system(size: 40))
        }
        .onAppear {
            ringScale   = 1.5
            ringOpacity = 0.0
        }
    }
}

// MARK: - D. LivePressureSparkline

private struct LiveSparklineCard: View {
    @StateObject private var monitor = MemoryMonitor.shared
    @State private var samples: [MemorySample] = []
    @State private var cancellable: AnyCancellable?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PRESSURE HISTORY")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(DS.textMuted)
                .tracking(1)

            Canvas { ctx, size in
                let vals = samples.suffix(40).map { $0.usedPercent }
                guard vals.count > 1 else { return }
                let n    = vals.count
                let maxV = max(vals.max() ?? 1, 1)
                let xStep = size.width / CGFloat(n - 1)

                func pt(_ i: Int) -> CGPoint {
                    CGPoint(
                        x: CGFloat(i) * xStep,
                        y: size.height - CGFloat(vals[i] / maxV) * size.height
                    )
                }

                // Build line path
                var line = Path()
                line.move(to: pt(0))
                for i in 1..<n {
                    let prev = pt(i - 1)
                    let curr = pt(i)
                    let cpDx = (curr.x - prev.x) * 0.5
                    line.addCurve(to: curr,
                                  control1: CGPoint(x: prev.x + cpDx, y: prev.y),
                                  control2: CGPoint(x: curr.x - cpDx, y: curr.y))
                }

                // Fill area under the line
                var fill = line
                fill.addLine(to: CGPoint(x: CGFloat(n-1) * xStep, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()

                let level = monitor.pressureLevel
                ctx.fill(fill, with: .color(level.color.opacity(0.18)))

                // Gradient effect for top-to-bottom fade is approximated via opacity
                ctx.stroke(line, with: .color(level.color.opacity(0.85)), lineWidth: 1.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.border, lineWidth: 0.5))

            HStack {
                Text(String(format: "%.0f%%", samples.last?.usedPercent ?? 0))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(monitor.pressureLevel.color)
                Text("used")
                    .font(.system(size: 10))
                    .foregroundColor(DS.textMuted)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .onAppear {
            samples = Array(monitor.pressureHistory.elements.suffix(40))
            cancellable = Timer.publish(every: 0.5, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    samples = Array(monitor.pressureHistory.elements.suffix(40))
                }
        }
        .onDisappear { cancellable?.cancel() }
    }
}

// MARK: - E. LiveMemoryDonut

private struct LiveDonutCard: View {
    @StateObject private var monitor = MemoryMonitor.shared
    @State private var fractions: [Double] = [0.25, 0.25, 0.25, 0.25]
    @State private var cancellable: AnyCancellable?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MEMORY BREAKDOWN")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(DS.textMuted)
                .tracking(1)

            HStack(spacing: 10) {
                // Donut canvas
                Canvas { ctx, size in
                    let cx = size.width / 2, cy = size.height / 2
                    let outerR: CGFloat = 42, innerR: CGFloat = 28
                    let lineW = outerR - innerR

                    let colors: [Color] = [DS.memWired, DS.memCompressed, DS.memApp, DS.memFree]
                    var startAngle = -90.0
                    for (i, frac) in fractions.enumerated() {
                        guard frac > 0 else { continue }
                        let sweep = frac * 360
                        var p = Path()
                        p.addArc(
                            center: CGPoint(x: cx, y: cy),
                            radius: (outerR + innerR) / 2,
                            startAngle: .degrees(startAngle),
                            endAngle:   .degrees(startAngle + sweep),
                            clockwise: false
                        )
                        ctx.stroke(p, with: .color(colors[i % colors.count]), lineWidth: lineW)
                        startAngle += sweep
                    }

                    // Centre: used %
                    let usedPct = Int(monitor.pressureHistory.elements.last?.usedPercent ?? 0)
                    ctx.draw(
                        Text("\(usedPct)%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(DS.textPrimary),
                        at: CGPoint(x: cx, y: cy),
                        anchor: .center
                    )
                }
                .frame(width: 90, height: 90)
                .animation(.spring(response: 0.5), value: fractions)

                // Legend
                VStack(alignment: .leading, spacing: 4) {
                    donutLegend(DS.memWired,      "Wired",  monitor.wiredBytes)
                    donutLegend(DS.memCompressed, "Comp",   monitor.compressedBytes)
                    donutLegend(DS.memApp,        "App",    monitor.appBytes)
                    donutLegend(DS.memFree,       "Free",   monitor.freeBytes)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .onAppear {
            updateFractions()
            cancellable = Timer.publish(every: 0.5, on: .main, in: .common)
                .autoconnect()
                .sink { _ in updateFractions() }
        }
        .onDisappear { cancellable?.cancel() }
    }

    private func updateFractions() {
        let total = Double(max(monitor.totalBytes, 1))
        withAnimation(.spring(response: 0.5)) {
            fractions = [
                Double(monitor.wiredBytes)      / total,
                Double(monitor.compressedBytes) / total,
                Double(monitor.appBytes)        / total,
                Double(monitor.freeBytes)       / total,
            ]
        }
    }

    private func donutLegend(_ color: Color, _ label: String, _ bytes: UInt64) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 9)).foregroundColor(DS.textMuted)
            Spacer()
            Text(formatBytes(Double(bytes)))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(DS.textSecondary)
        }
    }
}

// MARK: - F. AnimatedCounterView

private struct AnimatedCounterView: View {
    @State private var displayedGB: Double = 0
    private let actualGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

    var body: some View {
        Text(String(format: "%.1f GB RAM", displayedGB))
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(DS.memWired)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    displayedGB = actualGB
                }
            }
    }
}

// MARK: - G. PressureLevelBadge

private struct PressureLevelBadge: View {
    @StateObject private var monitor = MemoryMonitor.shared
    @State private var badgeScale: Double = 1.0
    @State private var lastLevel: PressureLevel = .normal

    var body: some View {
        let level = monitor.pressureLevel
        Text(level.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(level.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(level.color.opacity(0.15))
                    .overlay(Capsule().stroke(level.color.opacity(0.5), lineWidth: 1))
            )
            .scaleEffect(badgeScale)
            .onChange(of: level) { newLevel in
                // Pulse when level changes
                withAnimation(.easeInOut(duration: 0.4)) { badgeScale = 1.04 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 0.4)) { badgeScale = 1.0 }
                }
            }
    }
}

// MARK: - Feature Pills Grid

private struct FeaturePillsGrid: View {
    private let features: [(String)] = [
        "⚙ Kernel Pressure API",
        "🎨 4 Icon Styles",
        "⚡ Kill & Focus",
        "🔔 Smart Alerts",
        "📈 Trend Prediction",
        "🤖 Auto-Kill Rules",
        "🗓 Hourly Heatmap",
        "📥 CSV Export & Purge",
    ]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 5
        ) {
            ForEach(features, id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DS.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Capsule()
                            .fill(DS.surface)
                            .overlay(Capsule().stroke(DS.border, lineWidth: 0.5))
                    )
            }
        }
    }
}

// MARK: - System Info Card

private struct SystemInfoCard: View {
    private let cores = ProcessInfo.processInfo.processorCount
    private let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    private let osVer = ProcessInfo.processInfo.operatingSystemVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYSTEM")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(DS.textMuted)
                .tracking(1)

            AnimatedCounterView()

            HStack(spacing: 8) {
                sysChip("\(cores) cores")
                sysChip(String(format: "%.1f GB RAM", ramGB))
                sysChip("macOS \(osVer.majorVersion).\(osVer.minorVersion)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sysChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(DS.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DS.surface)
                    .overlay(Capsule().stroke(DS.border, lineWidth: 0.5))
            )
    }
}

// MARK: - Tagline Row

private struct TaglineRow: View {
    var body: some View {
        (
            Text("🧠")
            + Text(" From the minds of Daneyand & IBM Bob ")
                .font(.system(size: 13, weight: .medium))
            + Text("🤖")
        )
        .foregroundColor(DS.pressureElevated)
        .multilineTextAlignment(.center)
    }
}

// MARK: - Version Row

private struct VersionRow: View {
    var body: some View {
        Text("VERSION \(App.version)")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(DS.textMuted)
            .tracking(2)
    }
}
