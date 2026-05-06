import Foundation
import Observation

/// Polls "is anyone using the microphone?" once per second. When the mic has
/// been active for `pauseDebounceSeconds` consecutive seconds AND smart pause
/// is enabled, calls `engine.pause(.smartPauseCall)`. When the mic has been
/// quiet for `resumeDebounceSeconds` consecutive seconds, calls
/// `engine.resume(.smartPauseCall)`.
///
/// The debounce is asymmetric on purpose: pausing eagerly (5s) avoids the
/// break overlay landing two seconds into a meeting, while resuming slowly
/// (12s) avoids unpausing during a brief silence in conversation.
///
/// Mic-running is the signal that catches Google Meet in Chrome and other
/// browser-hosted calls — bundle-ID matching cannot. The previous CallDetector
/// (an enum that scanned `NSWorkspace.runningApplications`) was both
/// unreachable from the rest of the app AND unable to see browser meetings.
///
/// `micProbe` is injectable for testability — production uses `CoreAudioMicProbe`.
/// Held alive by the App as `@State`. Mirrors `IdleDetector`'s lifecycle.
@Observable
final class CallDetector {
    weak var engine: TimerEngine?

    private let clock: Clock
    private let isEnabled: () -> Bool
    private let pauseDebounceSeconds: TimeInterval
    private let resumeDebounceSeconds: TimeInterval
    private let micProbe: MicProbe

    private var tickHandle: ClockCancellable?
    private var sustainedActiveSeconds: TimeInterval = 0
    private var sustainedInactiveSeconds: TimeInterval = 0
    private(set) var isCurrentlyPausing = false

    init(
        clock: Clock = WallClock(),
        isEnabled: @escaping () -> Bool,
        pauseDebounceSeconds: TimeInterval = 5,
        resumeDebounceSeconds: TimeInterval = 12,
        micProbe: MicProbe = CoreAudioMicProbe()
    ) {
        self.clock = clock
        self.isEnabled = isEnabled
        self.pauseDebounceSeconds = pauseDebounceSeconds
        self.resumeDebounceSeconds = resumeDebounceSeconds
        self.micProbe = micProbe
    }

    /// Begins per-second polling. Idempotent.
    func start() {
        guard tickHandle == nil else { return }
        tickHandle = clock.schedule(every: 1.0) { [weak self] in
            self?.check()
        }
    }

    /// Public for tests; production code only calls `start()`.
    func check() {
        guard isEnabled() else {
            if isCurrentlyPausing {
                engine?.resume(.smartPauseCall)
                isCurrentlyPausing = false
            }
            sustainedActiveSeconds = 0
            sustainedInactiveSeconds = 0
            return
        }

        if micProbe.isMicActive() {
            sustainedActiveSeconds += 1
            sustainedInactiveSeconds = 0
        } else {
            sustainedInactiveSeconds += 1
            sustainedActiveSeconds = 0
        }

        if !isCurrentlyPausing && sustainedActiveSeconds >= pauseDebounceSeconds {
            engine?.pause(.smartPauseCall)
            isCurrentlyPausing = true
        } else if isCurrentlyPausing && sustainedInactiveSeconds >= resumeDebounceSeconds {
            engine?.resume(.smartPauseCall)
            isCurrentlyPausing = false
        }
    }
}
