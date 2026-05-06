import Foundation

/// A cancellable handle returned by `Clock.schedule`. Calling `cancel()` stops
/// future ticks. Cancellation is idempotent.
final class ClockCancellable {
    private var cancelHandler: (() -> Void)?

    init(_ cancelHandler: @escaping () -> Void) {
        self.cancelHandler = cancelHandler
    }

    func cancel() {
        cancelHandler?()
        cancelHandler = nil
    }

    deinit { cancel() }
}

/// Abstraction over wall-clock time. Production uses `WallClock`; tests use
/// `FakeClock` and call `advance(by:)` to drive scheduled ticks deterministically.
protocol Clock: AnyObject {
    var now: Date { get }
    func schedule(every interval: TimeInterval, _ tick: @escaping () -> Void) -> ClockCancellable
}

/// Real-time implementation backed by `Timer.scheduledTimer`.
final class WallClock: Clock {
    var now: Date { Date() }

    func schedule(every interval: TimeInterval, _ tick: @escaping () -> Void) -> ClockCancellable {
        // Construct unscheduled, then add to main run loop in .common mode so the
        // timer keeps firing while menus are tracking. Using `Timer.scheduledTimer`
        // would double-register (current thread + main).
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        return ClockCancellable { timer.invalidate() }
    }
}

/// Test double. `advance(by:)` synchronously fires every tick whose interval
/// would have elapsed during that span, in order.
final class FakeClock: Clock {
    private(set) var now: Date

    private struct Scheduled {
        let interval: TimeInterval
        var nextFire: Date
        let tick: () -> Void
        var cancelled: Bool
    }

    /// Append-only — `ClockCancellable` captures indices into this array.
    /// Do not compact or remove entries; rely on the `cancelled` flag instead.
    private var scheduled: [Scheduled] = []

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.now = start
    }

    func schedule(every interval: TimeInterval, _ tick: @escaping () -> Void) -> ClockCancellable {
        precondition(interval > 0, "FakeClock requires positive interval")
        let id = scheduled.count
        scheduled.append(Scheduled(
            interval: interval,
            nextFire: now.addingTimeInterval(interval),
            tick: tick,
            cancelled: false
        ))
        return ClockCancellable { [weak self] in
            guard let self, id < self.scheduled.count else { return }
            self.scheduled[id].cancelled = true
        }
    }

    /// Advance time by `duration`, firing every tick whose `nextFire` falls
    /// within the new window, in chronological order.
    func advance(by duration: TimeInterval) {
        let target = now.addingTimeInterval(duration)
        while let next = nextDueIndex(before: target) {
            now = scheduled[next].nextFire
            scheduled[next].nextFire = now.addingTimeInterval(scheduled[next].interval)
            scheduled[next].tick()
        }
        now = target
    }

    private func nextDueIndex(before cutoff: Date) -> Int? {
        scheduled.enumerated()
            .filter { !$0.element.cancelled && $0.element.nextFire <= cutoff }
            .min(by: { $0.element.nextFire < $1.element.nextFire })?
            .offset
    }
}
