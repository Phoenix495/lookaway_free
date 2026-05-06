import SwiftUI

struct PaperToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                configuration.label
                    .font(LAFont.bodyM)
                    .foregroundStyle(Color.laInk)
                Spacer(minLength: 0)
                pillSwitch(on: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: configuration.isOn)
    }

    @ViewBuilder
    private func pillSwitch(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: LARadius.pill, style: .continuous)
                .fill(on ? Color.laInk : Color.laPaper2)
                .overlay(
                    RoundedRectangle(cornerRadius: LARadius.pill, style: .continuous)
                        .stroke(Color.laInk, lineWidth: 1.2)
                )
            Circle()
                .fill(on ? Color.laPaper : Color.laInk)
                .padding(2)
        }
        .frame(width: 28, height: 16)
    }
}

extension ToggleStyle where Self == PaperToggleStyle {
    static var paper: PaperToggleStyle { PaperToggleStyle() }
}
