import SwiftUI

/// LookAway typography tokens. Maps to `--t-display-*`, `--t-body-*`, `--t-mono-*`.
/// Uses bundled fonts: Caveat (variable, display), Inter (Regular/Medium/SemiBold), JetBrainsMono (Medium/SemiBold).
enum LAFont {
    // Display (Caveat — variable weight)
    static let displayXL = Font.custom("Caveat", size: 88).weight(.bold)
    static let displayL  = Font.custom("Caveat", size: 44).weight(.medium)
    static let displayM  = Font.custom("Caveat", size: 30).weight(.medium)
    static let displayS  = Font.custom("Caveat", size: 24).weight(.medium)

    // Break overlay headline (Inter Regular — calm, large)
    static let breakHeadline = Font.custom("Inter-Regular", size: 48)

    // Body (Inter)
    static let bodyL  = Font.custom("Inter-Medium", size: 14)
    static let bodyM  = Font.custom("Inter-Regular", size: 13)
    static let bodyS  = Font.custom("Inter-Regular", size: 12)
    static let bodyXS = Font.custom("Inter-Regular", size: 11)

    // Mono (JetBrains Mono)
    static let monoXL = Font.custom("JetBrainsMono-SemiBold", size: 30).monospacedDigit()
    static let monoL  = Font.custom("JetBrainsMono-SemiBold", size: 22).monospacedDigit()
    static let monoM  = Font.custom("JetBrainsMono-Medium", size: 13).monospacedDigit()
    static let monoS  = Font.custom("JetBrainsMono-Medium", size: 11).monospacedDigit()
    static let caps   = Font.custom("JetBrainsMono-Medium", size: 10).monospacedDigit()
}

/// Helper for caps-style labels (uppercase + tracking).
extension Text {
    /// Apply LookAway caps treatment: caps font + uppercase + 1.5pt tracking + ink3 color.
    func laCaps() -> some View {
        self.font(LAFont.caps)
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Color.laInk3)
    }
}
