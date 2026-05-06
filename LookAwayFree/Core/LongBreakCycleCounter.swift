import Foundation

/// Wraps the regular `breakDuration` closure. After every Nth completed work
/// cycle, returns a longer "long break" duration instead of the regular one.
/// `N` is computed from the user's `longBreakInterval` setting divided by their
/// `workInterval` setting.
///
/// Used as the engine's `breakDuration` closure. Stateful — instantiated once
/// at app launch and held by the App.
final class LongBreakCycleCounter {
    private var breakCount = 0

    private let regularBreakDuration: () -> TimeInterval
    private let longBreakDuration: () -> TimeInterval
    private let longBreakInterval: () -> TimeInterval  // in seconds
    private let workInterval: () -> TimeInterval       // in seconds

    init(
        regularBreakDuration: @escaping () -> TimeInterval,
        longBreakDuration: @escaping () -> TimeInterval,
        longBreakInterval: @escaping () -> TimeInterval,
        workInterval: @escaping () -> TimeInterval
    ) {
        self.regularBreakDuration = regularBreakDuration
        self.longBreakDuration = longBreakDuration
        self.longBreakInterval = longBreakInterval
        self.workInterval = workInterval
    }

    /// Returns the next break's duration. Side effect: increments the internal
    /// counter. Use this as the engine's `breakDuration` closure parameter.
    func nextBreakDuration() -> TimeInterval {
        breakCount += 1

        let interval = longBreakInterval()
        let work = workInterval()

        guard interval > 0, work > 0 else {
            return regularBreakDuration()
        }

        let n = max(1, Int(round(interval / work)))
        if breakCount % n == 0 {
            return longBreakDuration()
        }
        return regularBreakDuration()
    }

    /// Returns true if the *next* call to `nextBreakDuration()` will yield a
    /// long break. UI can use this (e.g. menu "next: long break" hint). Read-only;
    /// does NOT increment the counter.
    var nextIsLongBreak: Bool {
        let interval = longBreakInterval()
        let work = workInterval()
        guard interval > 0, work > 0 else { return false }
        let n = max(1, Int(round(interval / work)))
        return (breakCount + 1) % n == 0
    }
}
