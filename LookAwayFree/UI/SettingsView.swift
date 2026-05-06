import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var launchManager: LaunchAtLoginManager

    @AppStorage(DurationKey.work) private var workSeconds: Double = DurationDefault.work
    @AppStorage(DurationKey.breakDur) private var breakSeconds: Double = DurationDefault.breakDur
    @AppStorage(DurationKey.snooze) private var snoozeSeconds: Double = DurationDefault.snooze
    @AppStorage(DurationKey.longBreakInterval) private var longBreakIntervalSeconds: Double = DurationDefault.longBreakInterval

    @AppStorage(PreferenceKey.soundsEnabled) private var soundsEnabled: Bool = PreferenceDefault.soundsEnabled
    @AppStorage(PreferenceKey.smartPauseEnabled) private var smartPauseEnabled: Bool = PreferenceDefault.smartPauseEnabled
    @AppStorage(PreferenceKey.allowSkipOnOverlay) private var allowSkipOnOverlay: Bool = PreferenceDefault.allowSkipOnOverlay

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Timer") {
                row(label: "Work interval", hint: "How long between breaks", isLast: false) {
                    PaperStepperView(value: workMinutes, range: 1...120, step: 1, suffix: " min")
                }
                row(label: "Break length", hint: "How long to look away", isLast: false) {
                    PaperStepperView(value: $breakSeconds, range: 5...300, step: 5, suffix: " sec")
                }
                row(label: "Long break every", hint: "0 disables; replaces every Nth regular break", isLast: true) {
                    PaperStepperView(value: longBreakMinutes, range: 0...180, step: 5, suffix: " min")
                }
            }

            section("Behavior") {
                row(label: "Sounds", hint: "Soft chime when a break starts", isLast: false) {
                    Toggle("", isOn: $soundsEnabled).toggleStyle(.paper).labelsHidden()
                }
                row(label: "Smart pause", hint: "Pause during calls, screen-shares, idle", isLast: false) {
                    Toggle("", isOn: $smartPauseEnabled).toggleStyle(.paper).labelsHidden()
                }
                row(label: "Launch at login", hint: nil, isLast: true) {
                    Toggle("", isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { launchManager.setEnabled($0) }
                    ))
                    .toggleStyle(.paper)
                    .labelsHidden()
                }
            }

            section("Overlay") {
                row(label: "Allow skip", hint: "Show skip button on overlay", isLast: true) {
                    Toggle("", isOn: $allowSkipOnOverlay).toggleStyle(.paper).labelsHidden()
                }
            }

            HStack {
                Spacer()
                Button("Reset to 20-20-20", action: resetToDefaults)
                    .buttonStyle(.paperGhost)
                Button("Done", action: dismissWindow)
                    .buttonStyle(.paperPrimary)
            }
            .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 18, leading: 24, bottom: 18, trailing: 24))
        .frame(width: 580)
        .background(Color.laPaper)
    }

    // MARK: - Section + row helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).laCaps().padding(.bottom, 6)
            content()
        }
    }

    @ViewBuilder
    private func row<Control: View>(
        label: String,
        hint: String?,
        isLast: Bool,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(LAFont.bodyL.weight(.medium)).foregroundStyle(Color.laInk)
                if let hint {
                    Text(hint).font(LAFont.bodyXS).foregroundStyle(Color.laInk3)
                }
            }
            Spacer()
            control()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !isLast {
                separator
            }
        }
    }

    private var separator: some View {
        // 1px dashed laInk4
        RoundedRectangle(cornerRadius: 0)
            .strokeBorder(
                Color.laInk4,
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Bindings (seconds <-> minutes for display)

    private var workMinutes: Binding<Double> {
        Binding(
            get: { workSeconds / 60 },
            set: { workSeconds = $0 * 60 }
        )
    }

    private var longBreakMinutes: Binding<Double> {
        Binding(
            get: { longBreakIntervalSeconds / 60 },
            set: { longBreakIntervalSeconds = $0 * 60 }
        )
    }

    // MARK: - Actions

    private func resetToDefaults() {
        workSeconds = DurationDefault.work
        breakSeconds = DurationDefault.breakDur
        snoozeSeconds = DurationDefault.snooze
        longBreakIntervalSeconds = DurationDefault.longBreakInterval
        soundsEnabled = PreferenceDefault.soundsEnabled
        smartPauseEnabled = PreferenceDefault.smartPauseEnabled
        allowSkipOnOverlay = PreferenceDefault.allowSkipOnOverlay
        // Note: launch-at-login is intentionally NOT reset here — it's a separate
        // user choice from "duration / sound defaults" and shouldn't be erased.
    }

    private func dismissWindow() {
        // Settings scene window — close via the focused window's standard close.
        NSApp.keyWindow?.performClose(nil)
    }
}
