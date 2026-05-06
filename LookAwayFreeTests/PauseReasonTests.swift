import Testing
@testable import LookAwayFree

@Suite("PauseReason")
struct PauseReasonTests {
    @Test("empty set is empty")
    func emptySetIsEmpty() {
        #expect(PauseReason([]).isEmpty)
    }

    @Test("inserting user and mic contains both")
    func insertingUserAndMicContainsBoth() {
        var reasons: PauseReason = []
        reasons.insert(.user)
        reasons.insert(.mic)
        #expect(reasons.contains(.user))
        #expect(reasons.contains(.mic))
    }

    @Test("removing one reason keeps the other")
    func removingOneReasonKeepsTheOther() {
        var reasons: PauseReason = [.user, .mic]
        reasons.remove(.user)
        #expect(!reasons.contains(.user))
        #expect(reasons.contains(.mic))
        #expect(!reasons.isEmpty)
    }

    @Test("removing all reasons is empty")
    func removingAllReasonsIsEmpty() {
        var reasons: PauseReason = [.user, .mic]
        reasons.remove(.user)
        reasons.remove(.mic)
        #expect(reasons.isEmpty)
    }

    @Test("double-inserting the same reason is idempotent")
    func doubleInsertSameReasonIsIdempotent() {
        var reasons: PauseReason = []
        reasons.insert(.user)
        reasons.insert(.user)
        #expect(reasons.contains(.user))
        // Removing once should clear it.
        reasons.remove(.user)
        #expect(reasons.isEmpty)
    }

    @Test("distinct reasons have distinct bits")
    func distinctReasonsHaveDistinctBits() {
        let all: [PauseReason] = [.user, .idle, .mic, .excludedApp, .officeHours, .systemSleep, .smartPauseIdle, .smartPauseCall, .smartPauseScreenShare]
        for (i, a) in all.enumerated() {
            for b in all.dropFirst(i + 1) {
                #expect(a.rawValue & b.rawValue == 0, "PauseReason flags must not share bits")
            }
        }
    }
}
