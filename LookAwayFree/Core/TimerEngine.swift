import Foundation
import Observation

/// Drives the work/break cycle. One instance is created at app launch,
/// `start()` is called once, and the engine runs until process exit.
/// There is intentionally no `stop()` or `reset()` — tests construct a
/// fresh engine per test; production deinit relies on ARC + the
/// `ClockCancellable` self-cancellation to clean up the scheduled tick.
@Observable
final class TimerEngine {
    /// The current state. Observers re-render when this changes.
    private(set) var state: TimerState = .idle

    /// Fraction of the current cycle elapsed (0...1). UI hint only.
    /// Reads from a cached cycle total set at each transition — the duration
    /// closures must NOT be called on every UI read because some
    /// implementations (e.g. `LongBreakCycleCounter.nextBreakDuration`) have
    /// side effects.
    var progressFraction: Double {
        let remaining: Double
        switch state {
        case .idle:
            return 0
        case .working(let r), .onBreak(let r):
            remaining = r
        case .paused(.working(let r), _), .paused(.onBreak(let r), _):
            remaining = r
        }
        let total = currentCycleTotal
        guard total > 0 else { return 0 }
        let elapsed = total - remaining
        return min(1, max(0, elapsed / total))
    }

    /// Total duration of the cycle currently reflected in `state`. Updated
    /// at every transition that consumes a duration closure. `progressFraction`
    /// reads this rather than re-invoking the closures.
    private var currentCycleTotal: TimeInterval = 0

    private let clock: Clock
    private let workDuration: () -> TimeInterval
    private let breakDuration: () -> TimeInterval
    private let onBreakStart: () -> Void
    private let onBreakEnd: () -> Void

    private var tickHandle: ClockCancellable?

    init(
        clock: Clock,
        workDuration: @escaping () -> TimeInterval,
        breakDuration: @escaping () -> TimeInterval,
        onBreakStart: @escaping () -> Void = {},
        onBreakEnd: @escaping () -> Void = {}
    ) {
        self.clock = clock
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.onBreakStart = onBreakStart
        self.onBreakEnd = onBreakEnd
    }

    /// Begins the work countdown from a fresh `workDuration()`.
    ///
    /// No-op if the engine is not in `.idle` (i.e. has already been started).
    /// There is no `stop()` — the engine runs until deinit, which cancels the
    /// scheduled tick via `ClockCancellable.deinit`.
    func start() {
        guard case .idle = state else { return }
        let total = workDuration()
        currentCycleTotal = total
        state = .working(remaining: total)
        tickHandle = clock.schedule(every: 1.0) { [weak self] in
            self?.tick()
        }
    }

    /// Pause for `reason`. See implementation in Task 6.
    func pause(_ reason: PauseReason) {
        switch state {
            case .idle:
                break
            case .working(let remaining):
                state = .paused(previous: .working(remaining: remaining), reasons: reason)
            case .onBreak(let remaining):
                state = .paused(previous: .onBreak(remaining: remaining), reasons: reason)
            case .paused(let previous, var reasons):
                reasons.insert(reason)
                state = .paused(previous: previous, reasons: reasons)
        }
    }

    /// Resume from `reason`. See implementation in Task 6.
    func resume(_ reason: PauseReason) {
        switch state {
            case .idle, .working, .onBreak:
                break
            case .paused(let previous, var reasons):
                reasons.remove(reason)
                guard reasons.isEmpty else {
                    state = .paused(previous: previous, reasons: reasons)
                    return
                }
                switch previous {
                    case .working(let remaining):
                        state = .working(remaining: remaining)
                    case .onBreak(let remaining):
                        state = .onBreak(remaining: remaining)
                }
        }
    }

    /// End an in-progress break early and return to `.working`. See Task 7.
    func skipBreak() {
        guard case .onBreak = state else { return }
        let total = workDuration()
        currentCycleTotal = total
        state = .working(remaining: total)
        onBreakEnd()
    }

    /// Forces a break to begin immediately from `.working`. No-op from any
    /// other state. Mirrors the natural work→break transition: reads
    /// `breakDuration()` fresh and fires `onBreakStart()` exactly once.
    func forceBreak() {
        guard case .working = state else { return }
        let total = breakDuration()
        currentCycleTotal = total
        state = .onBreak(remaining: total)
        onBreakStart()
    }

    /// Add `extra` seconds to `remaining` in `.working` or `.onBreak`. See Task 7 / Task 20.
    /// Also extends `currentCycleTotal` so the progress fraction stays sane.
    func snooze(_ extra: TimeInterval) {
        guard extra > 0 else { return }
        switch state {
        case .working(let r):
            currentCycleTotal += extra
            state = .working(remaining: r + extra)
        case .onBreak(let r):
            currentCycleTotal += extra
            state = .onBreak(remaining: r + extra)
        case .idle, .paused:
            return
        }
    }

    /// Called once per second by the injected `Clock`. See Task 5.
    private func tick() {
        switch state {
            case .working(var remaining):
                remaining -= 1
                if remaining.isZero {
                    let total = breakDuration()
                    currentCycleTotal = total
                    state = .onBreak(remaining: total)
                    onBreakStart()
                } else {
                    state = .working(remaining: remaining)
                }
            case .onBreak(var remaining):
                remaining -= 1
                if remaining.isZero {
                    let total = workDuration()
                    currentCycleTotal = total
                    state = .working(remaining: total)
                    onBreakEnd()
                } else {
                    state = .onBreak(remaining: remaining)
                }
            default:
                break
        }
    }
}
