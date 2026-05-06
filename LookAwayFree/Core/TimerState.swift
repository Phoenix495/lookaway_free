import Foundation

/// What the engine was doing immediately before being paused. Used to restore
/// the prior state when all pause reasons clear.
enum PreviousState: Equatable {
    case working(remaining: TimeInterval)
    case onBreak(remaining: TimeInterval)
}

/// The engine's full lifecycle state.
enum TimerState: Equatable {
    /// Created but not started. No ticks running.
    case idle
    /// Counting down to the next break.
    case working(remaining: TimeInterval)
    /// A break is in progress.
    case onBreak(remaining: TimeInterval)
    /// Paused for one or more reasons. `previous` is what to restore when
    /// `reasons` becomes empty.
    case paused(previous: PreviousState, reasons: PauseReason)
}
