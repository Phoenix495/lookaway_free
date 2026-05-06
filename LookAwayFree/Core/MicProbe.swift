import CoreAudio
import Foundation

/// Abstraction over the "is anyone using the microphone?" signal so
/// `CallDetector` can be tested without touching the audio system.
protocol MicProbe {
    func isMicActive() -> Bool
}

/// Reads the system's default input device "running somewhere" flag — true
/// whenever any process has IO open on the microphone. Catches Google Meet in
/// Chrome, native Zoom, Discord, and anything else that opens the mic.
///
/// Uses only public CoreAudio APIs, requires no microphone permission, and
/// does NOT activate the orange mic indicator (it reads device state, not
/// audio content). Cheap enough to call once per second.
///
/// The default input device is looked up fresh on each call so that switching
/// AirPods or external mics is reflected without reinitializing.
final class CoreAudioMicProbe: MicProbe {
    func isMicActive() -> Bool {
        guard let device = defaultInputDeviceID() else { return false }
        return isDeviceRunningSomewhere(device)
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private func isDeviceRunningSomewhere(_ device: AudioDeviceID) -> Bool {
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            device,
            &address,
            0,
            nil,
            &size,
            &isRunning
        )
        return status == noErr && isRunning != 0
    }
}
