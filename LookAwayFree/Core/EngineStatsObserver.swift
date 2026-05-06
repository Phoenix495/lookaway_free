import Foundation
import Observation

/// Bridges `TimerEngine` state transitions and screen-time ticks into the
/// `BreakStatistics` data model. Held alive by the App via `@State`.
///
/// Heuristics for "break taken vs skipped":
/// - .working → .onBreak: count as `breaksDue` (a break is starting).
/// - .onBreak(r) → .working with r ≤ 1.5: NATURAL end → `breaksTaken`.
/// - .onBreak(r) → .working with r > 1.5: USER SKIP → `breaksSkipped`.
/// - .working(r1) → .working(r2) with r2 > r1: SNOOZE during work.
/// - .onBreak(r1) → .onBreak(r2) with r2 > r1: SNOOZE during break (+30s).
///
/// Screen-time ticker fires once per second; if engine state is `.working` or
/// `.onBreak`, increments the current hour bucket. If state is `.paused` with
/// any `smartPause*` reason, accumulates `smartPausedSeconds`.
@MainActor
final class EngineStatsObserver {
    private weak var engine: TimerEngine?
    private let stats: BreakStatistics
    private let clock: Clock
    private let calendar: Calendar

    private var lastState: TimerState = .idle
    private var tickHandle: ClockCancellable?

    init(
        engine: TimerEngine,
        stats: BreakStatistics,
        clock: Clock = WallClock(),
        calendar: Calendar = .current
    ) {
        self.engine = engine
        self.stats = stats
        self.clock = clock
        self.calendar = calendar
        self.lastState = engine.state
        scheduleStateObservation()
        startScreenTimeTicker()
    }

    deinit {
        tickHandle?.cancel()
    }

    // MARK: - State observation (re-arm pattern)

    private func scheduleStateObservation() {
        withObservationTracking { [weak self] in
            _ = self?.engine?.state
        } onChange: { [weak self] in
            // onChange runs before the mutation completes; defer reading the
            // new state to the next main-queue runloop iteration.
            Task { @MainActor [weak self] in
                self?.handleStateChange()
                self?.scheduleStateObservation()
            }
        }
    }

    private func handleStateChange() {
        guard let engine else { return }
        let newState = engine.state
        defer { lastState = newState }

        switch (lastState, newState) {
        case (.working, .onBreak):
            stats.recordBreakDue()

        case (.onBreak(let r), .working):
            if r <= 1.5 {
                stats.recordBreakTaken()
            } else {
                stats.recordBreakSkipped()
            }

        case (.working(let r1), .working(let r2)) where r2 > r1:
            stats.recordSnoozeUsed()

        case (.onBreak(let r1), .onBreak(let r2)) where r2 > r1:
            stats.recordSnoozeUsed()

        default:
            break
        }
    }

    // MARK: - Screen-time ticker

    private func startScreenTimeTicker() {
        tickHandle = clock.schedule(every: 1.0) { [weak self] in
            self?.tickScreenTime()
        }
    }

    private func tickScreenTime() {
        guard let engine else { return }
        let hour = calendar.component(.hour, from: Date())

        switch engine.state {
        case .working, .onBreak:
            stats.recordScreenTimeTick(hour: hour)
        case .paused(_, let reasons):
            if reasons.contains(.smartPauseIdle)
               || reasons.contains(.smartPauseCall)
               || reasons.contains(.smartPauseScreenShare) {
                stats.recordSmartPauseTime(seconds: 1)
            }
        case .idle:
            break
        }
    }
}
