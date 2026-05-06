import Testing
import Foundation
@testable import LookAwayFree

@Suite("BreakStatistics")
struct BreakStatisticsTests {

    private func freshDefaults() -> UserDefaults {
        let suiteName = "test-stats-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        d.removePersistentDomain(forName: suiteName)
        return d
    }

    /// A fixed reference date: 2026-05-01 12:00:00 UTC.
    private static let day1: Date = Date(timeIntervalSince1970: 1777982400)
    private static let day2: Date = day1.addingTimeInterval(24 * 3600)

    @Test("new stats has all zeros across all fields")
    func newStats_allZero() {
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { Self.day1 })
        #expect(s.breaksTaken == 0)
        #expect(s.breaksDue == 0)
        #expect(s.breaksSkipped == 0)
        #expect(s.breaksSnoozed == 0)
        #expect(s.smartPausedSeconds == 0)
        #expect(s.screenTimeSeconds == 0)
        #expect(s.hourlyScreenTime.count == 24)
        #expect(s.hourlyScreenTime.allSatisfy { $0 == 0 })
    }

    @Test("recordBreakDue increments")
    func recordBreakDue_increments() {
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { Self.day1 })
        s.recordBreakDue(); s.recordBreakDue()
        #expect(s.breaksDue == 2)
    }

    @Test("recordBreakTaken / Skipped / Snoozed each increment their own counter")
    func recordingMethods_incrementTheirCounters() {
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { Self.day1 })
        s.recordBreakTaken()
        s.recordBreakSkipped()
        s.recordSnoozeUsed()
        #expect(s.breaksTaken == 1)
        #expect(s.breaksSkipped == 1)
        #expect(s.breaksSnoozed == 1)
    }

    @Test("recordSmartPauseTime accumulates seconds")
    func smartPauseTime_accumulates() {
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { Self.day1 })
        s.recordSmartPauseTime(seconds: 30)
        s.recordSmartPauseTime(seconds: 90)
        #expect(s.smartPausedSeconds == 120)
    }

    @Test("recordSmartPauseTime ignores zero or negative input")
    func smartPauseTime_ignoresNonpositive() {
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { Self.day1 })
        s.recordSmartPauseTime(seconds: 0)
        s.recordSmartPauseTime(seconds: -10)
        #expect(s.smartPausedSeconds == 0)
    }

    @Test("recordScreenTimeTick increments hour bucket and total")
    func screenTimeTick_increments() {
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { Self.day1 })
        s.recordScreenTimeTick(hour: 12)
        s.recordScreenTimeTick(hour: 12)
        s.recordScreenTimeTick(hour: 13)
        #expect(s.hourlyScreenTime[12] == 2)
        #expect(s.hourlyScreenTime[13] == 1)
        #expect(s.screenTimeSeconds == 3)
    }

    @Test("recordScreenTimeTick clamps out-of-range hours")
    func screenTimeTick_clamps() {
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { Self.day1 })
        s.recordScreenTimeTick(hour: -1)  // ignored
        s.recordScreenTimeTick(hour: 24)  // ignored
        s.recordScreenTimeTick(hour: 25)  // ignored
        #expect(s.screenTimeSeconds == 0)
    }

    @Test("stats persist across instances within the same day")
    func persistsAcrossInstances() {
        let defaults = freshDefaults()
        let s1 = BreakStatistics(defaults: defaults, dateProvider: { Self.day1 })
        s1.recordBreakTaken()
        s1.recordBreakDue()
        s1.recordScreenTimeTick(hour: 9)
        let s2 = BreakStatistics(defaults: defaults, dateProvider: { Self.day1 })
        #expect(s2.breaksTaken == 1)
        #expect(s2.breaksDue == 1)
        #expect(s2.hourlyScreenTime[9] == 1)
        #expect(s2.screenTimeSeconds == 1)
    }

    @Test("midnight rollover resets in-memory state to zero on next access")
    func rollover_resetsToZero() {
        var now = Self.day1
        let s = BreakStatistics(defaults: freshDefaults(), dateProvider: { now })
        s.recordBreakTaken()
        s.recordBreakTaken()
        #expect(s.breaksTaken == 2)
        now = Self.day2  // advance the clock by 24h
        s.recordBreakDue()  // triggers ensureCurrentDay() rollover
        #expect(s.breaksTaken == 0)  // reset
        #expect(s.breaksDue == 1)    // new day's first record
    }

    @Test("after rollover, prior day's storage entry remains intact")
    func rollover_preservesPriorDayStorage() {
        let defaults = freshDefaults()
        var now = Self.day1
        let s = BreakStatistics(defaults: defaults, dateProvider: { now })
        s.recordBreakTaken()
        let day1Key = BreakStatistics.dayKey(for: Self.day1)
        let day2Key = BreakStatistics.dayKey(for: Self.day2)
        now = Self.day2
        s.recordBreakDue()
        // Both keys should exist in defaults.
        #expect(defaults.data(forKey: day1Key) != nil)
        #expect(defaults.data(forKey: day2Key) != nil)
        // Decode prior day to verify the count.
        if let data = defaults.data(forKey: day1Key),
           let decoded = try? JSONDecoder().decode(DailyStats.self, from: data) {
            #expect(decoded.breaksTaken == 1)
        } else {
            Issue.record("Prior-day stats failed to decode")
        }
    }

    @Test("dayKey format is stable: stats.YYYY-MM-DD")
    func dayKey_format() {
        // Use UTC time-zone-insensitive date; verify pattern shape.
        let key = BreakStatistics.dayKey(for: Self.day1)
        #expect(key.hasPrefix("stats."))
        // Suffix is YYYY-MM-DD = 10 chars
        let suffix = String(key.dropFirst("stats.".count))
        #expect(suffix.count == 10)
        #expect(suffix.contains("-"))
    }
}
