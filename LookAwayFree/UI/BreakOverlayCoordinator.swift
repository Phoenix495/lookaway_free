import AppKit
import SwiftUI

/// Manages one full-screen NSWindow per connected display. Created once at
/// app launch; reused across breaks. Subscribes to screen-parameter changes
/// so plug/unplug/resolution-change events are reflected live during a break.
final class BreakOverlayCoordinator {
    weak var engine: TimerEngine?

    private var windows: [NSWindow] = []
    private var isShowing = false
    private var screenChangeToken: NSObjectProtocol?

    /// Pool of break headlines. One is picked per `show()` and shared across
    /// all monitors so every screen displays the same message during a break.
    private static let messages = [
        "Take a break, look out the window",
        "Rest your eyes, find the horizon",
        "Pause a moment, gaze at the distance",
    ]
    private var currentMessage: String = messages[0]

    init() {
        screenChangeToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isShowing else { return }
            self.rebuildForCurrentScreens()
        }
    }

    deinit {
        if let token = screenChangeToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func show() {
        isShowing = true
        currentMessage = Self.messages.randomElement() ?? Self.messages[0]
        rebuildForCurrentScreens()
    }

    func hide() {
        isShowing = false
        for w in windows { w.orderOut(nil) }
        // Window instances retained for reuse on next break.
    }

    /// Tears down existing windows and constructs a fresh set covering every
    /// `NSScreen.screens` entry. Called at break start and on screen change.
    private func rebuildForCurrentScreens() {
        guard let engine else { return }
        for w in windows { w.orderOut(nil) }
        windows.removeAll(keepingCapacity: true)

        for screen in NSScreen.screens {
            let view = BreakOverlayView(engine: engine, message: currentMessage)
            let hosting = NSHostingController(rootView: view)
            let window = makeWindow(for: screen)
            window.contentViewController = hosting
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let w = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = false
        w.isReleasedWhenClosed = false
        return w
    }
}
