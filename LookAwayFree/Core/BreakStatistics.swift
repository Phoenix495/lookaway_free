import Foundation
import Observation

/// Daily stats payload stored under `stats.YYYY-MM-DD` keys in UserDefaults.
/// Plain `Codable` struct — separated from the `@Observable` wrapper for
/// cleaner serialization and clearer test assertions.
struct DailyStats: Codable, Equatable {
    var breaksTaken: Int = 0
    var breaksDue: Int = 0
    var breaksSkipped: Int = 0
    var breaksSnoozed: Int = 0
    var smartPausedSeconds: TimeInterval = 0
    var screenTimeSeconds: TimeInterval = 0
    /// 24 elements (hours 0...23). Index = local hour-of-day.
    var hourlyScreenTime: [TimeInterval] = Array(repeating: 0, count: 24)
}

/// Tracks today's break/screen-time statistics with UserDefaults-backed
/// persistence. Auto-rolls over to a fresh per-day state at local midnight
/// (detected on each public access via the injectable date provider).
///
/// Each `record*` call (a) ensures the in-memory snapshot reflects the
/// current day, (b) mutates the appropriate field, and (c) persists the
/// updated snapshot. SwiftUI views observing this class re-render on any
/// field change.
@Observable
final class BreakStatistics {
    private let defaults: UserDefaults
    private let dateProvider: () -> Date

    /// Day key currently in memory. Updated on rollover.
    private var currentDayKey: String

    private(set) var breaksTaken: Int = 0
    private(set) var breaksDue: Int = 0
    private(set) var breaksSkipped: Int = 0
    private(set) var breaksSnoozed: Int = 0
    private(set) var smartPausedSeconds: TimeInterval = 0
    private(set) var screenTimeSeconds: TimeInterval = 0
    private(set) var hourlyScreenTime: [TimeInterval] = Array(repeating: 0, count: 24)

    init(defaults: UserDefaults = .standard, dateProvider: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.dateProvider = dateProvider
        self.currentDayKey = Self.dayKey(for: dateProvider())
        load()
    }

    // MARK: - Public recording API

    /// A scheduled break is now starting (work→break transition).
    func recordBreakDue() {
        ensureCurrentDay()
        breaksDue += 1
        persist()
    }

    /// A break ran to natural completion (didn't get skipped).
    func recordBreakTaken() {
        ensureCurrentDay()
        breaksTaken += 1
        persist()
    }

    /// User clicked Skip Break.
    func recordBreakSkipped() {
        ensureCurrentDay()
        breaksSkipped += 1
        persist()
    }

    /// User clicked a Snooze entry.
    func recordSnoozeUsed() {
        ensureCurrentDay()
        breaksSnoozed += 1
        persist()
    }

    /// Smart-pause has been active for `seconds` more seconds.
    func recordSmartPauseTime(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        ensureCurrentDay()
        smartPausedSeconds += seconds
        persist()
    }

    /// Engine was in an active state (working or onBreak) for one more
    /// second; bucket it into the given hour (0...23, local time).
    func recordScreenTimeTick(hour: Int) {
        guard (0..<24).contains(hour) else { return }
        ensureCurrentDay()
        hourlyScreenTime[hour] += 1
        screenTimeSeconds += 1
        persist()
    }

    // MARK: - Day rollover machinery

    private func ensureCurrentDay() {
        let key = Self.dayKey(for: dateProvider())
        if key != currentDayKey {
            // Old day's snapshot is already persisted by the most-recent
            // record call. Reset in-memory and load whatever's stored under
            // the new day's key (likely zero).
            currentDayKey = key
            resetInMemory()
            load()
        }
    }

    private func resetInMemory() {
        breaksTaken = 0
        breaksDue = 0
        breaksSkipped = 0
        breaksSnoozed = 0
        smartPausedSeconds = 0
        screenTimeSeconds = 0
        hourlyScreenTime = Array(repeating: 0, count: 24)
    }

    private func load() {
        guard let data = defaults.data(forKey: currentDayKey),
              let decoded = try? JSONDecoder().decode(DailyStats.self, from: data)
        else {
            return  // nothing stored — keep zero defaults
        }
        breaksTaken = decoded.breaksTaken
        breaksDue = decoded.breaksDue
        breaksSkipped = decoded.breaksSkipped
        breaksSnoozed = decoded.breaksSnoozed
        smartPausedSeconds = decoded.smartPausedSeconds
        screenTimeSeconds = decoded.screenTimeSeconds
        // Defensive: storage may predate the 24-bucket invariant.
        hourlyScreenTime = decoded.hourlyScreenTime.count == 24
            ? decoded.hourlyScreenTime
            : Array(repeating: 0, count: 24)
    }

    private func persist() {
        let snapshot = DailyStats(
            breaksTaken: breaksTaken,
            breaksDue: breaksDue,
            breaksSkipped: breaksSkipped,
            breaksSnoozed: breaksSnoozed,
            smartPausedSeconds: smartPausedSeconds,
            screenTimeSeconds: screenTimeSeconds,
            hourlyScreenTime: hourlyScreenTime
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: currentDayKey)
        }
    }

    // MARK: - Day key formatting

    /// Format: `stats.YYYY-MM-DD` using `en_US_POSIX` locale + current time
    /// zone. Stable across app launches and locale changes.
    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return "stats.\(formatter.string(from: date))"
    }
}
