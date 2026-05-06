import AppKit
import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` for the Launch at Login toggle in Settings.
/// `isEnabled` is observable and reflects the system's current registration
/// state; it auto-refreshes whenever the app becomes active (so changes the
/// user makes in System Settings are picked up). Calls to `setEnabled(_:)` log
/// failures to the console rather than surfacing alerts — failed register
/// attempts simply revert the UI on next refresh.
@Observable
final class LaunchAtLoginManager {
    private(set) var isEnabled: Bool = false
    private var didBecomeActiveToken: NSObjectProtocol?

    init() {
        refresh()
        didBecomeActiveToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let t = didBecomeActiveToken {
            NotificationCenter.default.removeObserver(t)
        }
    }

    /// Attempts to register or unregister the app as a login item, then
    /// re-reads the actual system status. On failure (e.g. unsigned debug
    /// build), prints to console and the next `refresh()` will revert the
    /// observable state.
    func setEnabled(_ newValue: Bool) {
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[LaunchAtLogin] failed to set enabled=\(newValue): \(error)")
        }
        refresh()
    }

    /// Reads `SMAppService.mainApp.status` and updates `isEnabled` accordingly.
    /// `.enabled` is the only state that maps to "on"; `.notFound`,
    /// `.notRegistered`, and `.requiresApproval` all map to "off".
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
