import SwiftUI

// Color palette matching the original Electron app
extension Color {
    // Backgrounds
    static let appBackground = Color(hex: 0x1a1a2e)

    // Primary accent
    static let accent = Color(hex: 0x6366f1)
    static let accentHover = Color(hex: 0x5558e6)
    static let accentLight = Color(hex: 0xa5b4fc)
    static let accentLighter = Color(hex: 0xc7d2fe)

    // Text
    static let textPrimary = Color(hex: 0xe0e0e0)
    static let textSecondary = Color(hex: 0xaaaaaa)
    static let textTertiary = Color(hex: 0x666666)
    static let textHint = Color(hex: 0x888888)
    static let textLabel = Color(hex: 0x999999)

    // Semantic
    static let success = Color(hex: 0x4ade80)
    static let error = Color(hex: 0xef4444)
    static let errorLight = Color(hex: 0xf87171)
    static let warning = Color(hex: 0xf59e0b)
    static let sectionHeading = Color(hex: 0xa0a0ff)
    static let purple = Color(hex: 0x8b5cf6)

    // Borders
    static let borderDefault = Color.white.opacity(0.08)
    static let borderLight = Color.white.opacity(0.06)
    static let borderMedium = Color.white.opacity(0.1)
    static let borderStrong = Color.white.opacity(0.15)

    // Surface
    static let surfaceLight = Color.white.opacity(0.05)
    static let surfaceHover = Color.white.opacity(0.1)
    static let surfaceDark = Color(red: 30/255, green: 30/255, blue: 30/255, opacity: 0.92)

    // Recording
    static let recordingBg = Color(hex: 0xef4444).opacity(0.1)
    static let recordingBorder = Color(hex: 0xef4444).opacity(0.3)

    // Processing
    static let processingBg = Color(hex: 0x6366f1).opacity(0.1)
    static let processingBorder = Color(hex: 0x6366f1).opacity(0.3)

    // Model info
    static let modelInfoBg = Color(hex: 0xf59e0b).opacity(0.06)
    static let modelInfoBorder = Color(hex: 0xf59e0b).opacity(0.25)

    // Level bars
    static let barColor = Color(hex: 0x999999)

    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
