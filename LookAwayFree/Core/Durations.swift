import Foundation

/// Centralized `UserDefaults` keys for user-configurable durations.
/// All values stored as `Double` seconds.
enum DurationKey {
    static let work = "workSeconds"
    static let breakDur = "breakSeconds"
    static let snooze = "snoozeSeconds"
    static let longBreakInterval = "longBreakIntervalSeconds"   // ie "long break every X minutes" but stored as seconds for consistency
}

/// Default values used when no user value is stored. The 20-20-20 rule:
/// work 20 min, break 20 sec. Snooze defaults to 5 min as a common UX choice.
enum DurationDefault {
    static let work: TimeInterval = 20 * 60
    static let breakDur: TimeInterval = 20
    static let snooze: TimeInterval = 5 * 60
    static let longBreakInterval: TimeInterval = 60 * 60   // every 60 minutes of work
    static let longBreakLength: TimeInterval = 5 * 60      // 5-minute long break (fixed for MVP, no UI setting yet)
}

extension UserDefaults {
    /// Reads a `TimeInterval` for `key`, falling back to `defaultValue` if unset.
    /// `UserDefaults.double(forKey:)` returns 0 for unset keys, which is
    /// indistinguishable from an intentional 0 — this helper uses
    /// `object(forKey:)` to distinguish.
    func duration(forKey key: String, default defaultValue: TimeInterval) -> TimeInterval {
        guard object(forKey: key) != nil else { return defaultValue }
        return double(forKey: key)
    }
}
