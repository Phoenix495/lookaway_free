import SwiftUI

/// LookAway spacing scale. Maps to `--sp-*`.
enum LASpacing {
    static let sp1: CGFloat = 4
    static let sp2: CGFloat = 8
    static let sp3: CGFloat = 12
    static let sp4: CGFloat = 14
    static let sp5: CGFloat = 18
    static let sp6: CGFloat = 22
    static let sp7: CGFloat = 24
    static let sp8: CGFloat = 32
}

/// LookAway radius scale. Maps to `--r-*`.
enum LARadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let xl: CGFloat = 14
    static let pill: CGFloat = 999
}

/// LookAway shadow tokens.
enum LAShadow {
    /// Window-level shadow (Settings, Stats).
    static let window: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) =
        (Color.black.opacity(0.12), 30, 0, 8)
    /// Popover-level shadow (menu bar dropdown).
    static let popover: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) =
        (Color.black.opacity(0.10), 16, 0, 4)
}

/// Common time formatter — moved from MenuBarLabel for cross-surface use.
enum LATime {
    /// Format `seconds` as zero-padded `mm:ss`. Minutes overflow past 60.
    static func mmss(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
