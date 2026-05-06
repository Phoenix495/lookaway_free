import Testing
import Foundation
@testable import LookAwayFree

@Suite("LongBreakCycleCounter")
struct LongBreakCycleTests {

    // Helpers — use closures that return fixed values for predictability.
    private func makeCounter(
        regular: TimeInterval = 20,
        long: TimeInterval = 300,
        interval: TimeInterval = 60 * 60,
        work: TimeInterval = 20 * 60
    ) -> LongBreakCycleCounter {
        LongBreakCycleCounter(
            regularBreakDuration: { regular },
            longBreakDuration: { long },
            longBreakInterval: { interval },
            workInterval: { work }
        )
    }

    @Test("with longBreakInterval=0, every call returns regular")
    func disabled_returnsRegular() {
        let c = makeCounter(interval: 0)
        for _ in 0..<10 {
            #expect(c.nextBreakDuration() == 20)
        }
    }

    @Test("with workInterval=0, every call returns regular (avoids div-by-zero)")
    func zeroWork_returnsRegular() {
        let c = makeCounter(work: 0)
        for _ in 0..<5 {
            #expect(c.nextBreakDuration() == 20)
        }
    }

    @Test("interval=60min, work=20min => N=3, third break is long")
    func threeCycle() {
        let c = makeCounter(regular: 20, long: 300, interval: 60 * 60, work: 20 * 60)
        #expect(c.nextBreakDuration() == 20)   // 1st: regular
        #expect(c.nextBreakDuration() == 20)   // 2nd: regular
        #expect(c.nextBreakDuration() == 300)  // 3rd: long
        #expect(c.nextBreakDuration() == 20)   // 4th: regular
        #expect(c.nextBreakDuration() == 20)   // 5th: regular
        #expect(c.nextBreakDuration() == 300)  // 6th: long
    }

    @Test("interval=20min, work=20min => N=1, every break is long")
    func everyBreakLong() {
        let c = makeCounter(regular: 20, long: 300, interval: 20 * 60, work: 20 * 60)
        #expect(c.nextBreakDuration() == 300)
        #expect(c.nextBreakDuration() == 300)
    }

    @Test("nextIsLongBreak preview matches actual behavior")
    func nextIsLongBreakPreview() {
        let c = makeCounter(regular: 20, long: 300, interval: 60 * 60, work: 20 * 60)
        // Initially count=0; next call (1st) should NOT be long.
        #expect(c.nextIsLongBreak == false)
        _ = c.nextBreakDuration()
        // count=1; next (2nd) NOT long.
        #expect(c.nextIsLongBreak == false)
        _ = c.nextBreakDuration()
        // count=2; next (3rd) SHOULD be long.
        #expect(c.nextIsLongBreak == true)
        _ = c.nextBreakDuration()
        // count=3; next (4th) NOT long.
        #expect(c.nextIsLongBreak == false)
    }

    @Test("rounded N: interval=50min, work=20min => N=round(2.5)=3 (away from zero)")
    func rounding() {
        let c = makeCounter(regular: 20, long: 300, interval: 50 * 60, work: 20 * 60)
        // round(2.5) on Apple platforms = 3 (away from zero).
        #expect(c.nextBreakDuration() == 20)
        #expect(c.nextBreakDuration() == 20)
        #expect(c.nextBreakDuration() == 300)
    }
}
