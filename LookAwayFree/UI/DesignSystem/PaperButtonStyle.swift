import SwiftUI

struct PaperButtonStyle: ButtonStyle {
    enum Variant { case regular, primary, ghost }

    var variant: Variant = .regular
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LAFont.bodyM.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background(pressed: configuration.isPressed))
            .foregroundStyle(foreground)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: LARadius.md, style: .continuous))
            .opacity(isEnabled ? 1.0 : 0.5)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch variant {
        case .regular: (pressed ? Color.laPaper3 : Color.laPaper).opacity(1)
        case .primary: (pressed ? Color.laInk2 : Color.laInk).opacity(1)
        case .ghost:   Color.clear
        }
    }

    private var foreground: Color {
        switch variant {
        case .regular, .ghost: return .laInk
        case .primary:         return .laPaper
        }
    }

    @ViewBuilder
    private var border: some View {
        let cornerRadius = LARadius.md
        switch variant {
        case .regular:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.laInk4, lineWidth: 1)
        case .primary:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.laInk, lineWidth: 1)
        case .ghost:
            EmptyView()
        }
    }
}

extension ButtonStyle where Self == PaperButtonStyle {
    static var paper: PaperButtonStyle { PaperButtonStyle(variant: .regular) }
    static var paperPrimary: PaperButtonStyle { PaperButtonStyle(variant: .primary) }
    static var paperGhost: PaperButtonStyle { PaperButtonStyle(variant: .ghost) }
}
