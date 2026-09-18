import SwiftUI

// MARK: - Design Tokens

enum DS {

    // ── Background & Surface ────────────────────────────────────────────────
    static let bg           = Color(red: 0.07, green: 0.07, blue: 0.10)
    static let surface      = Color(red: 0.12, green: 0.12, blue: 0.17)
    static let surfaceHover = Color(red: 0.16, green: 0.16, blue: 0.22)

    // ── Border ──────────────────────────────────────────────────────────────
    static let border       = Color.white.opacity(0.08)
    static let borderBright = Color.white.opacity(0.15)

    // ── Text ────────────────────────────────────────────────────────────────
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textMuted     = Color.white.opacity(0.30)

    // ── Pressure Level Colors ───────────────────────────────────────────────
    /// Normal  — Mint green  #44D97A
    static let pressureNormal   = Color(red: 0.267, green: 0.851, blue: 0.478)
    /// Elevated — Amber       #F5C842
    static let pressureElevated = Color(red: 0.961, green: 0.784, blue: 0.259)
    /// Warning  — Orange      #F58A1F
    static let pressureWarning  = Color(red: 0.961, green: 0.541, blue: 0.122)
    /// Critical — Red         #F04E4E
    static let pressureCritical = Color(red: 0.941, green: 0.306, blue: 0.306)
    /// Swap     — Violet      #9D6BF5
    static let pressureSwap     = Color(red: 0.616, green: 0.420, blue: 0.961)

    // ── Memory Region Colors ────────────────────────────────────────────────
    /// Wired       — Blue
    static let memWired      = Color(red: 0.36, green: 0.72, blue: 1.0)
    /// Compressed  — Violet
    static let memCompressed = Color(red: 0.56, green: 0.42, blue: 1.0)
    /// App (active)— Amber
    static let memApp        = Color(red: 0.96, green: 0.78, blue: 0.26)
    /// Free        — Dark gray
    static let memFree       = Color(red: 0.30, green: 0.30, blue: 0.35)

    // ── Layout ──────────────────────────────────────────────────────────────
    static let cornerRadius: CGFloat = 16
    static let cardPadding:  CGFloat = 16
    static let spacing:      CGFloat = 12

    // ── Typography ──────────────────────────────────────────────────────────
    static let fontMono = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let fontCaption = Font.system(size: 11, weight: .regular)
    static let fontLabel   = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let fontTitle   = Font.system(size: 14, weight: .bold, design: .rounded)
}

// MARK: - Card Container

struct MetricCard<Content: View>: View {
    let content: Content
    var glowColor: Color = .clear

    init(glowColor: Color = .clear, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.glowColor = glowColor
    }

    var body: some View {
        content
            .padding(DS.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .fill(DS.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                            .stroke(DS.border, lineWidth: 1)
                    )
                    .shadow(color: glowColor.opacity(0.12), radius: 20, x: 0, y: 0)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title:    String
    let subtitle: String?
    let color:    Color

    init(_ title: String, subtitle: String? = nil, color: Color = DS.textPrimary) {
        self.title    = title
        self.subtitle = subtitle
        self.color    = color
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(title)
                .font(DS.fontLabel)
                .foregroundStyle(DS.textPrimary)
            if let sub = subtitle {
                Text(sub)
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Byte Formatter

func formatBytes(_ bytes: Double, perSecond: Bool = false) -> String {
    let suffix = perSecond ? "/s" : ""
    switch bytes {
    case ..<1_024:
        return String(format: "%.0f B\(suffix)", bytes)
    case ..<(1_024 * 1_024):
        return String(format: "%.1f KB\(suffix)", bytes / 1_024)
    case ..<(1_024 * 1_024 * 1_024):
        return String(format: "%.1f MB\(suffix)", bytes / 1_048_576)
    default:
        return String(format: "%.2f GB\(suffix)", bytes / 1_073_741_824)
    }
}
