import AppKit
import SwiftUI

struct MenuContent: View {
    let engine: TimerEngine
    let stats: BreakStatistics
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @AppStorage(PreferenceKey.soundsEnabled) private var soundsEnabled: Bool = PreferenceDefault.soundsEnabled
    @AppStorage(PreferenceKey.smartPauseEnabled) private var smartPauseEnabled: Bool = PreferenceDefault.smartPauseEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let banner = smartPauseBannerText {
                smartPauseBanner(text: banner)
                    .padding(.horizontal, LASpacing.sp4)
                    .padding(.top, LASpacing.sp3)
            }

            ringWidget
                .padding(.top, LASpacing.sp5)
                .padding(.bottom, LASpacing.sp2)

            actionGrid
                .padding(.horizontal, LASpacing.sp3)

            sparklineStrip
                .padding(.horizontal, LASpacing.sp4)
                .padding(.top, LASpacing.sp3)
                .padding(.bottom, LASpacing.sp2)

            Divider()
                .background(Color.laInk4)
                .padding(.horizontal, LASpacing.sp3)

            bottomRow
                .padding(.horizontal, LASpacing.sp4)
                .padding(.vertical, LASpacing.sp2)
        }
        .frame(width: 320)
        .padding(.bottom, LASpacing.sp1)
        .background(Color.laPaper)
    }

    // MARK: - Ring widget

    @ViewBuilder
    private var ringWidget: some View {
        ZStack {
            Circle()
                .stroke(Color.laInk4, style: StrokeStyle(lineWidth: 3, dash: [3, 4]))

            Circle()
                .trim(from: 0, to: engine.progressFraction)
                .stroke(ringArcColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: engine.progressFraction)

            VStack(spacing: 4) {
                Text(centerTime)
                    .font(LAFont.monoXL)
                    .foregroundStyle(centerTextColor)
                Text(centerCaps)
                    .laCaps()
            }
        }
        .frame(width: 140, height: 140)
        .frame(maxWidth: .infinity)
    }

    private var ringArcColor: Color {
        switch engine.state {
        case .onBreak: return .laGood
        case .paused, .idle: return .laInk3
        case .working: return .laAccent
        }
    }

    private var centerTime: String {
        switch engine.state {
        case .idle, .paused: return "—:—"
        case .working(let r), .onBreak(let r): return LATime.mmss(r)
        }
    }

    private var centerCaps: String {
        switch engine.state {
        case .idle: return "Ready"
        case .working: return "Til Break"
        case .onBreak: return "Break · Look Away"
        case .paused: return "Paused"
        }
    }

    private var centerTextColor: Color {
        switch engine.state {
        case .idle, .paused: return .laInk3
        case .onBreak: return .laGood
        case .working: return .laInk
        }
    }

    // MARK: - Action grid

    private var actionGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
        return LazyVGrid(columns: cols, spacing: 6) {
            // Pause / Resume
            Button(pauseTitle) { togglePause() }
                .buttonStyle(.paper)
                .disabled(isIdle)
                .frame(maxWidth: .infinity)

            // Skip
            Button("Skip") { engine.skipBreak() }
                .buttonStyle(.paper)
                .disabled(!isOnBreak)
                .frame(maxWidth: .infinity)

            // Break now
            Button("Break now") { engine.forceBreak() }
                .buttonStyle(.paperPrimary)
                .disabled(!isWorking)
                .frame(maxWidth: .infinity)

            // Snooze (Menu)
            Menu {
                Button("1 minute")    { engine.snooze(1 * 60) }
                Button("5 minutes")   { engine.snooze(5 * 60) }
                Button("15 minutes")  { engine.snooze(15 * 60) }
                Button("30 minutes")  { engine.snooze(30 * 60) }
            } label: {
                Text("Snooze ▾")
                    .font(LAFont.bodyM.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.paper)
            .disabled(!isWorking)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sparkline

    private var sparklineStrip: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Today").laCaps()
            sparklineBars
            Text("\(stats.breaksTaken)/\(stats.breaksDue)")
                .font(LAFont.monoS)
                .foregroundStyle(Color.laInk2)
        }
    }

    private var sparklineBars: some View {
        let firstHour = 8
        let lastHour = 21  // 9pm; 14 buckets total (8...21)
        let visible = stats.hourlyScreenTime[firstHour...lastHour]
        let maxValue = max(1, visible.max() ?? 1)
        let currentHour = Calendar.current.component(.hour, from: Date())

        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(firstHour...lastHour, id: \.self) { hour in
                let value = stats.hourlyScreenTime[hour]
                let fraction = value / maxValue
                let isCurrent = hour == currentHour
                Rectangle()
                    .fill(isCurrent ? Color.laAccent : Color.laInk2)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(2, 24 * fraction))
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .opacity(value > 0 ? 1 : 0.15)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 24, alignment: .bottom)
    }

    // MARK: - Smart-paused banner

    private var smartPauseBannerText: String? {
        guard case .paused(_, let reasons) = engine.state else { return nil }
        if reasons.contains(.smartPauseCall) { return "◐ Smart-paused — resumes when call ends" }
        if reasons.contains(.smartPauseScreenShare) { return "◐ Smart-paused — resumes when share ends" }
        if reasons.contains(.smartPauseIdle) { return "◐ Smart-paused — resumes when you're back" }
        return nil
    }

    @ViewBuilder
    private func smartPauseBanner(text: String) -> some View {
        Text(text)
            .font(LAFont.bodyXS)
            .foregroundStyle(Color.laWarn)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LARadius.md, style: .continuous)
                    .fill(Color.laWarnSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LARadius.md, style: .continuous)
                    .stroke(Color.laWarn, lineWidth: 1)
            )
    }

    // MARK: - Bottom row

    private var bottomRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.laInk2)
                    .help("Sounds")
                Toggle("", isOn: $soundsEnabled)
                    .toggleStyle(.paper)
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .frame(width: 24, height: 14)
            }
            HStack(spacing: 4) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.laInk2)
                    .help("Smart Pause — auto-pause on calls, screen-share, or idle")
                Toggle("", isOn: $smartPauseEnabled)
                    .toggleStyle(.paper)
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .frame(width: 24, height: 14)
            }
            Spacer()
            Button {
                openWindow(id: "stats")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "chart.bar")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.laInk2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("1")
            .help("Open Stats…")

            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.laInk2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",")
            .help("Settings…")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.laInk2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .help("Quit")
        }
    }

    // MARK: - Derived state

    private var pauseTitle: String {
        if case .paused = engine.state { return "Resume" }
        return "Pause"
    }

    private var isIdle: Bool {
        if case .idle = engine.state { return true }
        return false
    }

    private var isOnBreak: Bool {
        if case .onBreak = engine.state { return true }
        return false
    }

    private var isWorking: Bool {
        if case .working = engine.state { return true }
        return false
    }

    private func togglePause() {
        if case .paused = engine.state {
            engine.resume(.user)
        } else {
            engine.pause(.user)
        }
    }
}
