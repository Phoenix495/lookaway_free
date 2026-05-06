import Foundation

/// Reasons a TimerEngine pause is active. Stacks: pausing for two reasons and
/// releasing one keeps the engine paused. Resume only happens when the set is empty.
struct PauseReason: OptionSet, Equatable, Hashable {
    let rawValue: Int

    init(rawValue: Int) { self.rawValue = rawValue }

    /// User explicitly paused via the menu.
    static let user        = PauseReason(rawValue: 1 << 0)
    /// User has been idle longer than the break duration. (v1)
    static let idle        = PauseReason(rawValue: 1 << 1)
    /// Microphone is in use by another app (call/recording). (v1)
    static let mic         = PauseReason(rawValue: 1 << 2)
    /// Frontmost app is on the user's exclusion list. (v1)
    static let excludedApp = PauseReason(rawValue: 1 << 3)
    /// Outside configured office hours. (v1)
    static let officeHours = PauseReason(rawValue: 1 << 4)
    /// macOS system is asleep. (v1)
    static let systemSleep = PauseReason(rawValue: 1 << 5)
    static let smartPauseIdle        = PauseReason(rawValue: 1 << 6)  // v1
    static let smartPauseCall        = PauseReason(rawValue: 1 << 7)  // v1
    static let smartPauseScreenShare = PauseReason(rawValue: 1 << 8)  // v1
}
