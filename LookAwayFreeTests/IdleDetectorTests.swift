import Testing
import Foundation
@testable import LookAwayFree

@Suite("IdleDetector")
@MainActor
struct IdleDetectorTests {

    final class IdleBox {
        var seconds: TimeInterval = 0
    }

    private func makeEngine(clock: Clock) -> TimerEngine {
        TimerEngine(
            clock: clock,
            workDuration: { 60 },
            breakDuration: { 10 }
        )
    }

    private func makeDetector(
        clock: Clock,
        engine: TimerEngine,
        threshold: TimeInterval = 60,
        enabled: Bool = true,
        idleBox: IdleBox
    ) -> IdleDetector {
        let det = IdleDetector(
            clock: clock,
            thresholdSeconds: { threshold },
            isEnabled: { enabled },
            idleSecondsProvider: { idleBox.seconds }
        )
        det.engine = engine
        return det
    }

    @Test("when isEnabled=false, never pauses regardless of idle")
    func disabled_neverPauses() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let box = IdleBox()
        let det = IdleDetector(
            clock: clock,
            thresholdSeconds: { 60 },
            isEnabled: { false },
            idleSecondsProvider: { box.seconds }
        )
        det.engine = engine
        det.start()
        box.seconds = 1000
        clock.advance(by: 5)
        // Engine should still be in .working, not .paused.
        if case .paused = engine.state {
            Issue.record("Engine got paused with smart pause disabled")
        }
        #expect(det.isCurrentlyPausing == false)
    }

    @Test("idle below threshold does not pause")
    func belowThreshold_noPause() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let box = IdleBox()
        box.seconds = 30  // below 60s threshold
        let det = makeDetector(clock: clock, engine: engine, idleBox: box)
        det.start()
        clock.advance(by: 5)
        #expect(det.isCurrentlyPausing == false)
    }

    @Test("idle at or above threshold pauses with .smartPauseIdle")
    func aboveThreshold_pauses() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let box = IdleBox()
        box.seconds = 70  // above 60s threshold
        let det = makeDetector(clock: clock, engine: engine, idleBox: box)
        det.start()
        clock.advance(by: 1)  // one tick
        #expect(det.isCurrentlyPausing == true)
        if case .paused(_, let reasons) = engine.state {
            #expect(reasons.contains(.smartPauseIdle))
        } else {
            Issue.record("Engine not paused after idle exceeded threshold")
        }
    }

    @Test("activity after pause resumes the engine")
    func activityResumes() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let box = IdleBox()
        box.seconds = 70
        let det = makeDetector(clock: clock, engine: engine, idleBox: box)
        det.start()
        clock.advance(by: 1)
        #expect(det.isCurrentlyPausing == true)
        // Activity → idle resets to 0.
        box.seconds = 0
        clock.advance(by: 1)
        #expect(det.isCurrentlyPausing == false)
        if case .paused = engine.state {
            Issue.record("Engine still paused after activity")
        }
    }

    @Test("starting twice is idempotent (no double tick)")
    func startTwice_idempotent() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let box = IdleBox()
        let det = makeDetector(clock: clock, engine: engine, idleBox: box)
        det.start()
        det.start()
        // If two ticks ran each second, the second call to pause(.smartPauseIdle)
        // would be idempotent in OptionSet so no observable diff. This test
        // mostly guards against duplicated tickHandles leaking timers — we just
        // check we don't crash.
        box.seconds = 70
        clock.advance(by: 3)
        #expect(det.isCurrentlyPausing == true)
    }
}
