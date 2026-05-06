import AppKit
import CoreGraphics
import Foundation
import Observation

/// Polls the system's idle time once per second. When idle exceeds the
/// configured threshold AND smart pause is enabled, calls
/// `engine.pause(.smartPauseIdle)`. On activity (idle drops below the
/// threshold), calls `engine.resume(.smartPauseIdle)`. Held alive by the App
/// as `@State`.
///
/// `idleSecondsProvider` is injectable for testability — production uses
/// `IdleDetector.systemIdleSeconds`. The `Clock` abstraction (same one
/// `TimerEngine` uses) drives the per-second tick, so tests can step time
/// deterministically with `FakeClock`.
@Observable
final class IdleDetector {
    weak var engine: TimerEngine?

    private let clock: Clock
    private let thresholdSeconds: () -> TimeInterval
    private let isEnabled: () -> Bool
    private let idleSecondsProvider: () -> TimeInterval

    private var tickHandle: ClockCancellable?
    private(set) var isCurrentlyPausing = false

    init(
        clock: Clock = WallClock(),
        thresholdSeconds: @escaping () -> TimeInterval = { 60 },
        isEnabled: @escaping () -> Bool,
        idleSecondsProvider: @escaping () -> TimeInterval = IdleDetector.systemIdleSeconds
    ) {
        self.clock = clock
        self.thresholdSeconds = thresholdSeconds
        self.isEnabled = isEnabled
        self.idleSecondsProvider = idleSecondsProvider
    }

    /// Begins per-second polling. Idempotent; calling twice does nothing.
    func start() {
        guard tickHandle == nil else { return }
        tickHandle = clock.schedule(every: 1.0) { [weak self] in
            self?.check()
        }
    }

    /// Public for tests; production code only calls `start()`.
    func check() {
        // Smart pause turned off — release any pause we hold.
        guard isEnabled() else {
            if isCurrentlyPausing {
                engine?.resume(.smartPauseIdle)
                isCurrentlyPausing = false
            }
            return
        }

        let idle = idleSecondsProvider()
        let threshold = thresholdSeconds()

        if idle >= threshold && !isCurrentlyPausing {
            engine?.pause(.smartPauseIdle)
            isCurrentlyPausing = true
        } else if idle < threshold && isCurrentlyPausing {
            engine?.resume(.smartPauseIdle)
            isCurrentlyPausing = false
        }
    }

    /// Production idle-time provider — reads from CoreGraphics. Returns the
    /// number of seconds since the last user input event of any type.
    static func systemIdleSeconds() -> TimeInterval {
        // `CGEventType(rawValue: ~0)` is the documented "any event type" sentinel
        // (kCGAnyInputEventType in C). It returns idle time across mouse,
        // keyboard, scroll, etc. `secondsSinceLastEventType` is a static
        // method on `CGEventSource` (not an instance method).
        guard let anyType = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyType)
    }
}
