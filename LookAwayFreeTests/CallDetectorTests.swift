import Testing
import Foundation
@testable import LookAwayFree

@Suite("CallDetector")
@MainActor
struct CallDetectorTests {

    final class FakeMicProbe: MicProbe {
        var active = false
        func isMicActive() -> Bool { active }
    }

    private func makeEngine(clock: Clock) -> TimerEngine {
        TimerEngine(clock: clock, workDuration: { 600 }, breakDuration: { 60 })
    }

    private func makeDetector(
        clock: Clock,
        engine: TimerEngine,
        probe: FakeMicProbe,
        enabled: Bool = true,
        pauseDebounce: TimeInterval = 5,
        resumeDebounce: TimeInterval = 12
    ) -> CallDetector {
        let det = CallDetector(
            clock: clock,
            isEnabled: { enabled },
            pauseDebounceSeconds: pauseDebounce,
            resumeDebounceSeconds: resumeDebounce,
            micProbe: probe
        )
        det.engine = engine
        return det
    }

    @Test("mic active below pause debounce does not pause")
    func micActive_belowDebounce_noPause() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        let det = makeDetector(clock: clock, engine: engine, probe: probe)
        det.start()
        clock.advance(by: 4)
        #expect(det.isCurrentlyPausing == false)
    }

    @Test("mic active for pause debounce triggers .smartPauseCall")
    func micActive_atDebounce_pauses() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        let det = makeDetector(clock: clock, engine: engine, probe: probe)
        det.start()
        clock.advance(by: 5)
        #expect(det.isCurrentlyPausing == true)
        if case .paused(_, let reasons) = engine.state {
            #expect(reasons.contains(.smartPauseCall))
        } else {
            Issue.record("Engine not paused after mic active for debounce")
        }
    }

    @Test("mic inactive below resume debounce does not resume")
    func micInactive_belowDebounce_noResume() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        let det = makeDetector(clock: clock, engine: engine, probe: probe)
        det.start()
        clock.advance(by: 5)
        #expect(det.isCurrentlyPausing == true)
        probe.active = false
        clock.advance(by: 11)
        #expect(det.isCurrentlyPausing == true)
    }

    @Test("mic inactive for resume debounce resumes")
    func micInactive_atDebounce_resumes() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        let det = makeDetector(clock: clock, engine: engine, probe: probe)
        det.start()
        clock.advance(by: 5)
        probe.active = false
        clock.advance(by: 12)
        #expect(det.isCurrentlyPausing == false)
        if case .paused = engine.state {
            Issue.record("Engine still paused after mic inactive for debounce")
        }
    }

    @Test("brief mic-off flicker resets the pause debounce counter")
    func flicker_resetsPauseDebounce() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        let det = makeDetector(clock: clock, engine: engine, probe: probe)
        det.start()
        clock.advance(by: 4)
        probe.active = false
        clock.advance(by: 1)
        probe.active = true
        clock.advance(by: 4)
        #expect(det.isCurrentlyPausing == false)
        clock.advance(by: 1)
        #expect(det.isCurrentlyPausing == true)
    }

    @Test("when isEnabled=false, never pauses regardless of mic")
    func disabled_neverPauses() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        let det = makeDetector(clock: clock, engine: engine, probe: probe, enabled: false)
        det.start()
        clock.advance(by: 30)
        #expect(det.isCurrentlyPausing == false)
        if case .paused = engine.state {
            Issue.record("Engine got paused with smart pause disabled")
        }
    }

    @Test("disabling toggle mid-pause releases the pause immediately")
    func toggleOff_midPause_releases() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        var enabled = true
        let det = CallDetector(
            clock: clock,
            isEnabled: { enabled },
            pauseDebounceSeconds: 5,
            resumeDebounceSeconds: 12,
            micProbe: probe
        )
        det.engine = engine
        det.start()
        clock.advance(by: 5)
        #expect(det.isCurrentlyPausing == true)
        enabled = false
        clock.advance(by: 1)
        #expect(det.isCurrentlyPausing == false)
        if case .paused = engine.state {
            Issue.record("Engine still paused after toggle off")
        }
    }

    @Test("starting twice is idempotent")
    func startTwice_idempotent() {
        let clock = FakeClock()
        let engine = makeEngine(clock: clock)
        engine.start()
        let probe = FakeMicProbe()
        probe.active = true
        let det = makeDetector(clock: clock, engine: engine, probe: probe)
        det.start()
        det.start()
        clock.advance(by: 5)
        #expect(det.isCurrentlyPausing == true)
    }
}
