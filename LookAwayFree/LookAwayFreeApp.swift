//
//  LookAwayFreeApp.swift
//  LookAwayFree
//
//  Created by Vitalii Serheiev on 30.04.2026.
//

import SwiftUI

@main
struct LookAwayFreeApp: App {
    @State private var engine: TimerEngine
    @State private var coordinator: BreakOverlayCoordinator
    @State private var sleepObserver: SleepWakeObserver
    @State private var launchManager: LaunchAtLoginManager
    @State private var stats: BreakStatistics
    @State private var longBreakCounter: LongBreakCycleCounter
    @State private var idleDetector: IdleDetector
    @State private var callDetector: CallDetector
    @State private var statsObserver: EngineStatsObserver

    init() {
        let coord = BreakOverlayCoordinator()
        let breakStats = BreakStatistics()

        let counter = LongBreakCycleCounter(
            regularBreakDuration: {
                UserDefaults.standard.duration(forKey: DurationKey.breakDur, default: DurationDefault.breakDur)
            },
            longBreakDuration: { DurationDefault.longBreakLength },
            longBreakInterval: {
                UserDefaults.standard.duration(forKey: DurationKey.longBreakInterval, default: DurationDefault.longBreakInterval)
            },
            workInterval: {
                UserDefaults.standard.duration(forKey: DurationKey.work, default: DurationDefault.work)
            }
        )

        let eng = TimerEngine(
            clock: WallClock(),
            workDuration: {
                UserDefaults.standard.duration(forKey: DurationKey.work, default: DurationDefault.work)
            },
            breakDuration: counter.nextBreakDuration,
            onBreakStart: { [weak coord] in
                coord?.show()
                SoundPlayer.playBreakStart()
            },
            onBreakEnd: { [weak coord] in
                coord?.hide()
                SoundPlayer.playBreakEnd()
            }
        )
        coord.engine = eng   // safe to set now that both exist; coord holds engine weakly

        let sleepObs = SleepWakeObserver(engine: eng)
        let lm = LaunchAtLoginManager()

        let idle = IdleDetector(
            isEnabled: {
                UserDefaults.standard.bool(forKey: PreferenceKey.smartPauseEnabled, default: PreferenceDefault.smartPauseEnabled)
            }
        )
        idle.engine = eng
        idle.start()

        let call = CallDetector(
            isEnabled: {
                UserDefaults.standard.bool(forKey: PreferenceKey.smartPauseEnabled, default: PreferenceDefault.smartPauseEnabled)
            }
        )
        call.engine = eng
        call.start()

        let observer = EngineStatsObserver(engine: eng, stats: breakStats)

        eng.start()

        _engine = State(initialValue: eng)
        _coordinator = State(initialValue: coord)
        _sleepObserver = State(initialValue: sleepObs)
        _launchManager = State(initialValue: lm)
        _stats = State(initialValue: breakStats)
        _longBreakCounter = State(initialValue: counter)
        _idleDetector = State(initialValue: idle)
        _callDetector = State(initialValue: call)
        _statsObserver = State(initialValue: observer)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(engine: engine, stats: stats)
        } label: {
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(launchManager: launchManager)
        }

        Window("LookAway Stats", id: "stats") {
            StatsView(stats: stats)
        }
        .defaultSize(width: 720, height: 560)
    }
}
