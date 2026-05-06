import Testing
import Foundation
@testable import LookAwayFree

@Suite("TimerEngine")
struct TimerEngineTests {
    // Swift Testing creates a fresh instance per @Test, so these initialize
    // cleanly for every test — no manual setUp/reset required.
    let clock = FakeClock()

    final class CallbackCounters {
        var breakStartCount = 0
        var breakEndCount = 0
    }
    let counters = CallbackCounters()

    private func makeEngine(work: TimeInterval = 60, breakDur: TimeInterval = 10) -> TimerEngine {
        TimerEngine(
            clock: clock,
            workDuration: { work },
            breakDuration: { breakDur },
            onBreakStart: { [counters] in counters.breakStartCount += 1 },
            onBreakEnd:   { [counters] in counters.breakEndCount += 1 }
        )
    }

    // MARK: - tick() tests

    @Test("start puts engine in .working with full duration")
    func startPutsEngineInWorkingWithFullDuration() {
        let engine = makeEngine(work: 60)
        engine.start()
        #expect(engine.state == .working(remaining: 60))
    }

    @Test("tick decrements working remaining by one per second")
    func tickDecrementsWorkingRemainingByOnePerSecond() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 3)
        #expect(engine.state == .working(remaining: 57))
    }

    @Test("working remaining hitting zero transitions to .onBreak")
    func workingRemainingHittingZeroTransitionsToOnBreak() {
        let engine = makeEngine(work: 3, breakDur: 10)
        engine.start()
        clock.advance(by: 3)
        // Work→break is atomic inside tick(); no transient state in between.
        #expect(engine.state == .onBreak(remaining: 10))
    }

    @Test("working remaining hitting zero fires onBreakStart exactly once")
    func workingRemainingHittingZeroFiresOnBreakStartExactlyOnce() {
        let engine = makeEngine(work: 3, breakDur: 10)
        engine.start()
        clock.advance(by: 3)
        #expect(counters.breakStartCount == 1)
    }

    @Test("onBreak remaining hitting zero transitions to .working fresh")
    func onBreakRemainingHittingZeroTransitionsToWorkingFresh() {
        let engine = makeEngine(work: 60, breakDur: 5)
        engine.start()
        clock.advance(by: 60) // burn through work
        #expect(engine.state == .onBreak(remaining: 5))
        clock.advance(by: 5) // burn through break
        #expect(engine.state == .working(remaining: 60))
    }

    @Test("onBreak remaining hitting zero fires onBreakEnd exactly once")
    func onBreakRemainingHittingZeroFiresOnBreakEndExactlyOnce() {
        let engine = makeEngine(work: 60, breakDur: 5)
        engine.start()
        clock.advance(by: 60)
        clock.advance(by: 5)
        #expect(counters.breakEndCount == 1)
    }

    @Test("full cycle fires start and end once")
    func fullCycleFiresStartAndEndOnce() {
        let engine = makeEngine(work: 3, breakDur: 2)
        engine.start()
        clock.advance(by: 3 + 2)
        #expect(counters.breakStartCount == 1)
        #expect(counters.breakEndCount == 1)
        #expect(engine.state == .working(remaining: 3))
    }

    @Test("second cycle also fires start and end")
    func secondCycleAlsoFiresStartAndEnd() {
        let engine = makeEngine(work: 2, breakDur: 1)
        engine.start()
        clock.advance(by: 2 + 1) // first cycle done
        clock.advance(by: 2 + 1) // second cycle done
        #expect(counters.breakStartCount == 2)
        #expect(counters.breakEndCount == 2)
    }

    @Test("durations read from closure are picked up on next cycle")
    func durationsReadFromClosurePickedUpOnNextCycle() {
        final class Box { var work: TimeInterval = 5 }
        let box = Box()
        let engine = TimerEngine(
            clock: clock,
            workDuration: { box.work },
            breakDuration: { 1 },
            onBreakStart: {},
            onBreakEnd: {}
        )
        engine.start()
        clock.advance(by: 5 + 1) // finish first cycle, return to .working
        // Change the work duration after a cycle has completed.
        box.work = 10
        #expect(engine.state == .working(remaining: 5)) // current cycle unchanged
        clock.advance(by: 5 + 1) // finish second cycle
        #expect(engine.state == .working(remaining: 10)) // third cycle reads new duration
    }

    // MARK: - pause / resume tests

    @Test("pause from .working moves to .paused with same remaining")
    func pauseFromWorking_movesToPausedWithSameRemaining() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        #expect(engine.state == .paused(previous: .working(remaining: 55), reasons: [.user]))
    }

    @Test("pause from .onBreak moves to .paused with .onBreak previous")
    func pauseFromOnBreak_movesToPausedWithBreakPrevious() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        clock.advance(by: 60) // burn through work → .onBreak(remaining: 10)
        clock.advance(by: 2)  // → .onBreak(remaining: 8)
        #expect(engine.state == .onBreak(remaining: 8))
        engine.pause(.user)
        #expect(engine.state == .paused(previous: .onBreak(remaining: 8), reasons: [.user]))
    }

    @Test("pause from .idle is a silent no-op")
    func pauseFromIdle_isNoOp() {
        let engine = makeEngine()
        // Not started.
        engine.pause(.user)
        #expect(engine.state == .idle)
    }

    @Test("pause twice with same reason is idempotent (set semantics)")
    func pauseTwiceWithSameReason_isIdempotent() {
        let engine = makeEngine(work: 60)
        engine.start()
        engine.pause(.user)
        engine.pause(.user)
        guard case let .paused(_, reasons) = engine.state else {
            Issue.record("expected .paused state, got \(engine.state)")
            return
        }
        #expect(reasons == [.user])
    }

    @Test("pause with two different reasons unions the set")
    func pauseTwoDifferentReasons_unionsTheSet() {
        let engine = makeEngine(work: 60)
        engine.start()
        engine.pause(.user)
        engine.pause(.mic)
        guard case let .paused(_, reasons) = engine.state else {
            Issue.record("expected .paused state, got \(engine.state)")
            return
        }
        #expect(reasons.contains(.user))
        #expect(reasons.contains(.mic))
    }

    @Test("pause a second time does not overwrite previous")
    func pauseSecondTime_doesNotOverwritePrevious() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5) // .working(55)
        engine.pause(.user)
        clock.advance(by: 100) // no-op while paused
        engine.pause(.mic)
        guard case let .paused(previous, _) = engine.state else {
            Issue.record("expected .paused state, got \(engine.state)")
            return
        }
        #expect(previous == .working(remaining: 55))
    }

    @Test("tick while paused does not mutate state")
    func tickWhilePaused_doesNotMutateState() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        let before = engine.state
        clock.advance(by: 1000)
        #expect(engine.state == before)
        #expect(engine.state == .paused(previous: .working(remaining: 55), reasons: [.user]))
    }

    @Test("resume of only reason restores .working previous")
    func resumeOnlyReason_restoresPreviousWorking() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        engine.resume(.user)
        #expect(engine.state == .working(remaining: 55))
    }

    @Test("resume of only reason restores .onBreak previous")
    func resumeOnlyReason_restoresPreviousOnBreak() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        clock.advance(by: 60) // → .onBreak(remaining: 10)
        clock.advance(by: 2)  // → .onBreak(remaining: 8)
        #expect(engine.state == .onBreak(remaining: 8))
        engine.pause(.user)
        engine.resume(.user)
        #expect(engine.state == .onBreak(remaining: 8))
    }

    @Test("resume one of two reasons stays paused with remaining reason")
    func resumeOneOfTwoReasons_staysPausedWithRemainingReason() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        engine.pause(.mic)
        engine.resume(.user)
        guard case let .paused(previous, reasons) = engine.state else {
            Issue.record("expected .paused state, got \(engine.state)")
            return
        }
        #expect(reasons == [.mic])
        #expect(previous == .working(remaining: 55))
    }

    @Test("resume of a reason not in the set is a no-op")
    func resumeReasonNotInSet_isNoOp() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        engine.resume(.mic)
        #expect(engine.state == .paused(previous: .working(remaining: 55), reasons: [.user]))
    }

    @Test("resume from .working (never paused) is a no-op")
    func resumeFromWorking_isNoOp() {
        let engine = makeEngine(work: 60)
        engine.start()
        engine.resume(.user)
        #expect(engine.state == .working(remaining: 60))
    }

    @Test("resume from .idle is a no-op")
    func resumeFromIdle_isNoOp() {
        let engine = makeEngine()
        engine.resume(.user)
        #expect(engine.state == .idle)
    }

    @Test("resume restores and the timer continues ticking")
    func resumeRestoresAndContinuesTicking() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        clock.advance(by: 1000) // paused, no decrement
        engine.resume(.user)
        clock.advance(by: 3)
        #expect(engine.state == .working(remaining: 52))
    }

    // MARK: - skipBreak tests

    @Test("skipBreak from .onBreak returns to fresh .working")
    func skipBreakFromOnBreak_returnsToFreshWorking() {
        let engine = makeEngine(work: 10, breakDur: 5)
        engine.start()
        clock.advance(by: 10) // → .onBreak(remaining: 5)
        #expect(engine.state == .onBreak(remaining: 5))
        engine.skipBreak()
        // Fresh workDuration(), NOT the leftover 5.
        #expect(engine.state == .working(remaining: 10))
    }

    @Test("skipBreak from .onBreak fires onBreakEnd exactly once")
    func skipBreakFromOnBreak_firesOnBreakEndExactlyOnce() {
        let engine = makeEngine(work: 10, breakDur: 5)
        engine.start()
        clock.advance(by: 10) // → .onBreak(remaining: 5)
        engine.skipBreak()
        #expect(counters.breakEndCount == 1)
    }

    @Test("skipBreak from .onBreak does not fire onBreakStart again")
    func skipBreakFromOnBreak_doesNotFireOnBreakStartAgain() {
        let engine = makeEngine(work: 10, breakDur: 5)
        engine.start()
        clock.advance(by: 10) // .onBreak — onBreakStart fired once here
        #expect(counters.breakStartCount == 1)
        engine.skipBreak()
        // Returning to .working must not re-fire onBreakStart.
        #expect(counters.breakStartCount == 1)
    }

    @Test("skipBreak from .idle is a silent no-op")
    func skipBreakFromIdle_isNoOp() {
        let engine = makeEngine()
        // Not started.
        engine.skipBreak()
        #expect(engine.state == .idle)
        #expect(counters.breakStartCount == 0)
        #expect(counters.breakEndCount == 0)
    }

    @Test("skipBreak from .working is a silent no-op")
    func skipBreakFromWorking_isNoOp() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5) // → .working(remaining: 55)
        engine.skipBreak()
        #expect(engine.state == .working(remaining: 55))
        #expect(counters.breakStartCount == 0)
        #expect(counters.breakEndCount == 0)
    }

    @Test("skipBreak from .paused is a silent no-op")
    func skipBreakFromPaused_isNoOp() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        let before = engine.state
        engine.skipBreak()
        #expect(engine.state == before)
        #expect(engine.state == .paused(previous: .working(remaining: 55), reasons: [.user]))
        #expect(counters.breakStartCount == 0)
        #expect(counters.breakEndCount == 0)
    }

    @Test("after skipBreak the tick continues as .working")
    func afterSkipBreak_tickContinuesAsWorking() {
        let workDur: TimeInterval = 10
        let engine = makeEngine(work: workDur, breakDur: 5)
        engine.start()
        clock.advance(by: 10) // → .onBreak(remaining: 5)
        engine.skipBreak()    // → .working(remaining: 10)
        clock.advance(by: 3)
        #expect(engine.state == .working(remaining: workDur - 3))
    }

    @Test("skipBreak reads fresh workDuration from closure")
    func skipBreak_readsFreshWorkDurationFromClosure() {
        final class Box {
            var work: TimeInterval = 10
        }
        let box = Box()
        let engine = TimerEngine(
            clock: clock,
            workDuration: { box.work },
            breakDuration: { 5 },
            onBreakStart: { [counters] in counters.breakStartCount += 1 },
            onBreakEnd:   { [counters] in counters.breakEndCount += 1 }
        )
        engine.start()
        clock.advance(by: 10) // burn through work → .onBreak(remaining: 5)
        #expect(engine.state == .onBreak(remaining: 5))
        // Mutate the closure's source after entering the break.
        box.work = 100
        engine.skipBreak()
        // skipBreak must read the *current* closure value, not a stale one.
        #expect(engine.state == .working(remaining: 100))
    }

    // MARK: - snooze tests

    @Test("snooze from .working adds extra seconds to remaining")
    func snoozeFromWorking_addsExtraSecondsToRemaining() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5) // → .working(remaining: 55)
        engine.snooze(120)
        #expect(engine.state == .working(remaining: 175))
    }

    @Test("snooze with zero is a no-op")
    func snoozeWithZero_isNoOp() {
        let engine = makeEngine(work: 60)
        engine.start()
        engine.snooze(0)
        #expect(engine.state == .working(remaining: 60))
    }

    @Test("snooze with negative is a no-op")
    func snoozeWithNegative_isNoOp() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5) // → .working(remaining: 55)
        engine.snooze(-30)
        #expect(engine.state == .working(remaining: 55))
    }

    @Test("snooze from .idle is a no-op")
    func snoozeFromIdle_isNoOp() {
        let engine = makeEngine()
        // Not started.
        engine.snooze(60)
        #expect(engine.state == .idle)
    }

    @Test("snooze during .onBreak extends remaining")
    func snoozeFromOnBreak_extendsRemaining() {
        let engine = makeEngine(work: 5, breakDur: 10)
        engine.start()
        clock.advance(by: 5)  // drives to .onBreak(remaining: 10)
        engine.snooze(15)
        #expect(engine.state == .onBreak(remaining: 25))
    }

    @Test("snooze from .paused is a no-op")
    func snoozeFromPaused_isNoOp() {
        let engine = makeEngine(work: 60)
        engine.start()
        clock.advance(by: 5)
        engine.pause(.user)
        engine.snooze(60)
        // Previous must remain .working(55), NOT .working(115).
        #expect(engine.state == .paused(previous: .working(remaining: 55), reasons: [.user]))
    }

    @Test("after snooze the tick continues normally")
    func afterSnooze_tickContinuesNormally() {
        let engine = makeEngine(work: 10)
        engine.start()
        engine.snooze(20) // → .working(remaining: 30)
        #expect(engine.state == .working(remaining: 30))
        clock.advance(by: 3)
        #expect(engine.state == .working(remaining: 27))
    }

    @Test("snooze multiple times — each accumulates")
    func snoozeMultipleTimes_eachAccumulates() {
        let engine = makeEngine(work: 60)
        engine.start()
        engine.snooze(30)
        engine.snooze(30)
        #expect(engine.state == .working(remaining: 120))
    }

    @Test("snooze accepts large extra — no upper bound")
    func snoozeAcceptsLargeExtra_noUpperBound() {
        let engine = makeEngine(work: 60)
        engine.start()
        engine.snooze(10_000)
        #expect(engine.state == .working(remaining: 10_060))
    }

    // MARK: - progressFraction tests

    @Test("progressFraction starts at zero in .idle")
    func progressFractionInIdle_isZero() {
        let engine = makeEngine(work: 60, breakDur: 10)
        #expect(engine.progressFraction == 0)
    }

    @Test("progressFraction in .working matches elapsed fraction")
    func progressFractionInWorking_matchesElapsed() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        #expect(engine.progressFraction == 0)         // just started
        clock.advance(by: 30)                         // halfway
        #expect(abs(engine.progressFraction - 0.5) < 0.01)
        clock.advance(by: 29)                         // almost done
        #expect(abs(engine.progressFraction - 59.0/60.0) < 0.01)
    }

    @Test("progressFraction in .onBreak matches elapsed fraction")
    func progressFractionInOnBreak_matchesElapsed() {
        let engine = makeEngine(work: 5, breakDur: 10)
        engine.start()
        clock.advance(by: 5)  // drives to .onBreak(remaining: 10)
        #expect(engine.progressFraction == 0)
        clock.advance(by: 5)  // halfway through break
        #expect(abs(engine.progressFraction - 0.5) < 0.01)
    }

    @Test("progressFraction in .paused reflects previous state")
    func progressFractionInPaused_reflectsPrevious() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        clock.advance(by: 30)  // half elapsed
        engine.pause(.user)
        #expect(abs(engine.progressFraction - 0.5) < 0.01)  // still 0.5 while paused
        clock.advance(by: 1000)  // no decrement while paused
        #expect(abs(engine.progressFraction - 0.5) < 0.01)
        engine.resume(.user)
        #expect(abs(engine.progressFraction - 0.5) < 0.01)  // resumes at same fraction
    }

    @Test("progressFraction is clamped to 0...1")
    func progressFraction_isClamped() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        // Even if duration closure returns 0 (edge case), shouldn't NaN/crash.
        let weirdEngine = TimerEngine(
            clock: clock,
            workDuration: { 0 },
            breakDuration: { 10 }
        )
        weirdEngine.start()
        #expect(weirdEngine.progressFraction >= 0)
        #expect(weirdEngine.progressFraction <= 1)
    }

    // MARK: - forceBreak tests

    @Test("forceBreak from .working transitions to .onBreak")
    func forceBreakFromWorking_transitionsToOnBreak() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        clock.advance(by: 5)
        engine.forceBreak()
        #expect(engine.state == .onBreak(remaining: 10))
    }

    @Test("forceBreak from .working fires onBreakStart exactly once")
    func forceBreakFromWorking_firesOnBreakStartOnce() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        engine.forceBreak()
        #expect(counters.breakStartCount == 1)
    }

    @Test("forceBreak reads fresh breakDuration from closure")
    func forceBreak_readsFreshBreakDuration() {
        final class Box { var breakDur: TimeInterval = 5 }
        let box = Box()
        let engine = TimerEngine(
            clock: clock,
            workDuration: { 60 },
            breakDuration: { box.breakDur }
        )
        engine.start()
        box.breakDur = 100
        engine.forceBreak()
        #expect(engine.state == .onBreak(remaining: 100))
    }

    @Test("forceBreak from .idle is no-op")
    func forceBreakFromIdle_isNoOp() {
        let engine = makeEngine(work: 60, breakDur: 10)
        // engine NOT started — still .idle
        engine.forceBreak()
        #expect(engine.state == .idle)
        #expect(counters.breakStartCount == 0)
    }

    @Test("forceBreak from .onBreak is no-op")
    func forceBreakFromOnBreak_isNoOp() {
        let engine = makeEngine(work: 5, breakDur: 10)
        engine.start()
        clock.advance(by: 5)  // drive to .onBreak
        let stateBefore = engine.state
        let countBefore = counters.breakStartCount
        engine.forceBreak()
        #expect(engine.state == stateBefore)
        #expect(counters.breakStartCount == countBefore)
    }

    @Test("forceBreak from .paused is no-op")
    func forceBreakFromPaused_isNoOp() {
        let engine = makeEngine(work: 60, breakDur: 10)
        engine.start()
        engine.pause(.user)
        let stateBefore = engine.state
        let countBefore = counters.breakStartCount
        engine.forceBreak()
        #expect(engine.state == stateBefore)
        #expect(counters.breakStartCount == countBefore)
    }
}
