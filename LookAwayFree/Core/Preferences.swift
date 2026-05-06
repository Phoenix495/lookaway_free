import Foundation

/// `UserDefaults` keys for non-duration user preferences.
enum PreferenceKey {
    static let soundsEnabled = "soundsEnabled"
    static let smartPauseEnabled = "smartPauseEnabled"
    static let allowSkipOnOverlay = "allowSkipOnOverlay"
}

/// Default values used when no user value is stored.
enum PreferenceDefault {
    static let soundsEnabled = true
    static let smartPauseEnabled = true
    static let allowSkipOnOverlay = true
}

extension UserDefaults {
    /// Reads a `Bool` for `key`, falling back to `defaultValue` if unset.
    /// `UserDefaults.bool(forKey:)` returns `false` for unset, indistinguishable
    /// from an explicit `false` — this helper uses `object(forKey:)` to
    /// distinguish.
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard object(forKey: key) != nil else { return defaultValue }
        return bool(forKey: key)
    }
}
