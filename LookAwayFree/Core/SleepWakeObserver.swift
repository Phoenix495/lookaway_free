import AppKit

/// Bridges macOS system sleep/wake notifications to the engine's pause/resume
/// API using the `.systemSleep` reason. Created once at app launch; observers
/// are torn down on deinit.
final class SleepWakeObserver {
    private weak var engine: TimerEngine?
    private var willSleepToken: NSObjectProtocol?
    private var didWakeToken: NSObjectProtocol?

    init(engine: TimerEngine) {
        self.engine = engine

        let center = NSWorkspace.shared.notificationCenter

        willSleepToken = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine?.pause(.systemSleep)
        }

        didWakeToken = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine?.resume(.systemSleep)
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let t = willSleepToken { center.removeObserver(t) }
        if let t = didWakeToken { center.removeObserver(t) }
    }
}
