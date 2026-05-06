import SwiftUI

/// Eye icon — matches `assets/menubar-icon.svg`. Outer circle + filled dot.
struct EyeIcon: View {
    /// Drawn on an 18×18 canvas. Caller can size with `.frame(width:height:)`.
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            // Stroke ratio: 1.5/18; outer radius ratio: 7/18; inner: 2/18.
            let stroke = w * (1.5 / 18.0)
            let outerRadius = w * (7.0 / 18.0)
            let innerRadius = w * (2.0 / 18.0)
            let center = CGPoint(x: w / 2, y: h / 2)
            let outerRect = CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
            let innerRect = CGRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            )
            // Outer circle: stroke only.
            context.stroke(
                Path(ellipseIn: outerRect),
                with: .color(.primary),
                lineWidth: stroke
            )
            // Inner dot: filled.
            context.fill(Path(ellipseIn: innerRect), with: .color(.primary))
        }
        .accessibilityHidden(true)
    }
}

/// SwiftUI view rendered as the menu bar label. Re-renders automatically when
/// the engine's `state` changes (engine is `@Observable`).
///
/// Display rules:
/// - `.idle`           -> eye icon only
/// - `.working(r)`     -> eye icon + " mm:ss"
/// - `.onBreak(r)`     -> eye icon + " mm:ss"
/// - `.paused(...)`    -> eye icon + " Paused"
struct MenuBarLabel: View {
    let engine: TimerEngine

    var body: some View {
        HStack(spacing: 4) {
            EyeIcon().frame(width: 14, height: 14)
            if let text = labelText {
                Text(text)
                    .font(LAFont.monoM)
            }
        }
    }

    private var labelText: String? {
        switch engine.state {
        case .idle:                            return nil
        case .working(let r), .onBreak(let r): return LATime.mmss(r)
        case .paused:                          return "Paused"
        }
    }

    /// Format `seconds` as zero-padded `mm:ss`. Kept for backwards compatibility
    /// with callers (`MenuContent`, `BreakOverlayView`) that may still reference
    /// this static. Prefer `LATime.mmss(_:)` for new usage.
    static func format(_ seconds: TimeInterval) -> String {
        LATime.mmss(seconds)
    }
}
