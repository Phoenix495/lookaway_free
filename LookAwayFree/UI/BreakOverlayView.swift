import SwiftUI

/// The SwiftUI content shown during a break. Re-renders on engine.state changes.
/// `skipEnabled` resets each break (fresh `@State` per view construction).
/// Layout: ZStack with a blurred desktop backdrop + dim tint, and centered
/// content (headline + progress + buttons) — no card container.
struct BreakOverlayView: View {
    let engine: TimerEngine
    let message: String
    @State private var skipEnabled = false

    private static let skipDelay: Duration = .seconds(5)

    var body: some View {
        ZStack {
            BlurBackdrop(material: .fullScreenUI)
                .ignoresSafeArea()

            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text(message)
                    .font(LAFont.breakHeadline)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                HStack(alignment: .center, spacing: 10) {
                    progressBar
                        .frame(width: 200, height: 3)
                    Text(LATime.mmss(remainingSeconds))
                        .font(LAFont.monoM)
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                HStack(spacing: 10) {
                    // Skip · esc — ghost button, always visible; disabled until
                    // the skip-delay elapses. Esc triggers it (no-op when disabled).
                    Button { engine.skipBreak() } label: {
                        Text("Skip · esc")
                            .font(LAFont.bodyXS.weight(.medium))
                            .foregroundStyle(Color.white.opacity(skipEnabled ? 0.85 : 0.35))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(skipEnabled ? 0.3 : 0.12), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape)
                    .disabled(!skipEnabled)
                    .animation(.easeIn(duration: 0.3), value: skipEnabled)

                    // +30 sec — extends the break (matches Skip · esc style)
                    Button { engine.snooze(30) } label: {
                        Text("+30 sec")
                            .font(LAFont.bodyXS.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
        }
        .task {
            try? await Task.sleep(for: Self.skipDelay)
            skipEnabled = true
        }
    }

    private var progressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.20))
                Capsule()
                    .fill(Color.laAccent)
                    .frame(width: g.size.width * engine.progressFraction)
            }
        }
    }

    private var remainingSeconds: TimeInterval {
        if case .onBreak(let r) = engine.state { return r }
        return 0
    }
}
