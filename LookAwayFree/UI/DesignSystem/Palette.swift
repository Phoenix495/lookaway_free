import AppKit
import SwiftUI

extension Color {
    /// Returns a Color whose underlying NSColor adapts to the current system appearance.
    /// `light` and `dark` are 0xRRGGBB hex literals (sRGB).
    static func laAdaptive(light: Int, dark: Int) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [
                .aqua, .vibrantLight, .accessibilityHighContrastAqua, .accessibilityHighContrastVibrantLight,
                .darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark
            ]).map { name in
                name == .darkAqua
                    || name == .vibrantDark
                    || name == .accessibilityHighContrastDarkAqua
                    || name == .accessibilityHighContrastVibrantDark
            } ?? false
            let hex = isDark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >> 8) & 0xFF) / 255.0
            let b = CGFloat(hex & 0xFF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        }))
    }
}

/// LookAway "Paper & Ink" palette. All colors are sRGB and adapt to the
/// current system appearance (light/dark). Tokens map to design-system CSS
/// variables in `colors_and_type.css`.
extension Color {
    // Paper / Ink (warm neutrals — adaptive)
    static let laPaper  = Color.laAdaptive(light: 0xfdfcf8, dark: 0x1f1d18)
    static let laPaper2 = Color.laAdaptive(light: 0xf4f1e8, dark: 0x2a2620)
    static let laPaper3 = Color.laAdaptive(light: 0xebe7d8, dark: 0x353029)

    static let laInk  = Color.laAdaptive(light: 0x1a1a1a, dark: 0xf0ebdf)
    static let laInk2 = Color.laAdaptive(light: 0x4a4a4a, dark: 0xb8b3a8)
    static let laInk3 = Color.laAdaptive(light: 0x8a8a8a, dark: 0x888888)
    static let laInk4 = Color.laAdaptive(light: 0xc4c4c4, dark: 0x5a5550)
    static let laInk5 = Color.laAdaptive(light: 0xe2dfd6, dark: 0x3a3530)

    // Semantic accents (slightly brighter in dark for legibility on dark surfaces)
    static let laAccent     = Color.laAdaptive(light: 0x4c7fa8, dark: 0x7daad0)
    static let laAccentSoft = Color.laAdaptive(light: 0xe4eaf2, dark: 0x2a3a4a)
    static let laAccentInk  = Color.laAdaptive(light: 0x335577, dark: 0xbcd3eb)

    static let laGood     = Color.laAdaptive(light: 0x5a9678, dark: 0x7ab592)
    static let laGoodSoft = Color.laAdaptive(light: 0xe5eee7, dark: 0x283830)

    static let laWarn     = Color.laAdaptive(light: 0xc76a47, dark: 0xd88766)
    static let laWarnSoft = Color.laAdaptive(light: 0xf3e6dd, dark: 0x3a2a20)

    static let laHi      = Color.laAdaptive(light: 0xd4b549, dark: 0xdac75a)
    static let laHiSoft  = Color.laAdaptive(light: 0xf3edd2, dark: 0x3a3320)
}
