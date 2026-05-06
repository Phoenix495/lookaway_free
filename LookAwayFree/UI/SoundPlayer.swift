import AppKit

/// Plays short audio cues at break boundaries. Reads the user's
/// `soundsEnabled` preference; if off, calls become no-ops.
enum SoundPlayer {
    static func playBreakStart() {
        guard soundsEnabled else { return }
        NSSound(named: "Glass")?.play()
    }

    static func playBreakEnd() {
        guard soundsEnabled else { return }
        NSSound(named: "Hero")?.play()
    }

    private static var soundsEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: PreferenceKey.soundsEnabled,
            default: PreferenceDefault.soundsEnabled
        )
    }
}
