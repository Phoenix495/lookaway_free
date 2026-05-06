import AppKit
import SwiftUI

/// `NSPanel` with `.nonactivatingPanel` is purpose-built for "HUD-style
/// windows that need keyboard focus without activating the owning app" —
/// the same class Spotlight uses. Unlike a plain `NSWindow`, this can
/// become key without requiring `NSApp.activate()`, which macOS Sonoma+
/// silently rejects for timer-driven contexts (no user gesture).
///
/// `becomesKeyOnlyIfNeeded` defaults to `true` for `NSPanel`, meaning
/// `makeKeyAndOrderFront(_:)` is a no-op unless something explicitly asks
/// to be first responder. We force it to `false` so the panel actually
/// claims key status as soon as it's shown.
private final class KeyableOverlayPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// Manages one full-screen NSWindow per connected display. Created once at
/// app launch; reused across breaks. Subscribes to screen-parameter changes
/// so plug/unplug/resolution-change events are reflected live during a break.
final class BreakOverlayCoordinator {
    weak var engine: TimerEngine?

    private var windows: [NSWindow] = []
    private var isShowing = false
    private var screenChangeToken: NSObjectProtocol?
    private var breakStartedAt: Date?

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
        breakStartedAt = Date()
        currentMessage = Self.messages.randomElement() ?? Self.messages[0]
        // No app activation needed: `KeyableOverlayPanel` is a non-activating
        // panel that becomes key on its own without requiring the app to be
        // the front-most application.
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

        for (index, screen) in NSScreen.screens.enumerated() {
            let view = BreakOverlayView(engine: engine, message: currentMessage)
            let hosting = NSHostingController(rootView: view)
            let window = makeWindow(for: screen)
            window.contentViewController = hosting
            window.setFrame(screen.frame, display: true)
            // Only the first window becomes key — keyboard input only needs one
            // window in the responder chain, and multi-monitor setups should not
            // fight over key status.
            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
            windows.append(window)
        }
    }

    /// Called by `KeyableOverlayPanel` when ESC is pressed. Silently
    /// ignores the keypress for the first `BreakOverlayView.skipDelay`
    /// seconds of every break to match the visual disabled state of the
    /// Skip button (single source of truth lives on the view).
    private func handleEscape() {
        guard let started = breakStartedAt,
              Date().timeIntervalSince(started) >= BreakOverlayView.skipDelay else { return }
        engine?.skipBreak()
    }

    private func makeWindow(for screen: NSScreen) -> KeyableOverlayPanel {
        let w = KeyableOverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // NSPanel defaults this to true, which would make `makeKeyAndOrderFront`
        // a no-op for a borderless panel with no first-responder requestors.
        w.becomesKeyOnlyIfNeeded = false
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = false
        w.isReleasedWhenClosed = false
        w.onCancel = { [weak self] in self?.handleEscape() }
        return w
    }
}
