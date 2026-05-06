import AppKit
import SwiftUI

/// SwiftUI wrapper around `NSVisualEffectView` for use as a backdrop. With
/// `blendingMode = .behindWindow`, the effect blurs and tints whatever sits
/// behind the host window — for the break overlay, that's the user's desktop
/// and any other windows beneath the overlay.
///
/// Requires the host `NSWindow` to be translucent (`isOpaque = false`,
/// `backgroundColor = .clear`). The break overlay coordinator already
/// configures windows that way.
struct BlurBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = state
        v.autoresizingMask = [.width, .height]
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
