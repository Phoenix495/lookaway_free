import SwiftUI

/// Paper-themed numeric stepper component — drop-in replacement for SwiftUI's
/// `Stepper`. Used in Settings.
struct PaperStepperView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String
    /// How to render the numeric portion. Default: `Int(value)`.
    var format: (Double) -> String = { String(Int($0)) }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: decrement) { Text("−").frame(minWidth: 24, minHeight: 22) }
                .buttonStyle(.plain)
                .disabled(value <= range.lowerBound)
            Divider().frame(height: 14).overlay(Color.laInk3)
            Text("\(format(value))\(suffix)")
                .font(LAFont.monoM)
                .foregroundStyle(Color.laInk)
                .frame(minWidth: 60)
                .padding(.horizontal, 6)
            Divider().frame(height: 14).overlay(Color.laInk3)
            Button(action: increment) { Text("+").frame(minWidth: 24, minHeight: 22) }
                .buttonStyle(.plain)
                .disabled(value >= range.upperBound)
        }
        .overlay(
            RoundedRectangle(cornerRadius: LARadius.md, style: .continuous)
                .stroke(Color.laInk, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: LARadius.md, style: .continuous))
        .font(LAFont.monoM)
        .foregroundStyle(Color.laInk)
    }

    private func decrement() {
        value = max(range.lowerBound, value - step)
    }

    private func increment() {
        value = min(range.upperBound, value + step)
    }
}
