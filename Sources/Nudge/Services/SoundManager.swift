import AppKit

/// Available system sounds that can be assigned to notification types.
enum SoundChoice: String, CaseIterable, Identifiable, Sendable {
    case glass    = "Glass"
    case ping     = "Ping"
    case pop      = "Pop"
    case purr     = "Purr"
    case basso    = "Basso"
    case blow     = "Blow"
    case bottle   = "Bottle"
    case frog     = "Frog"
    case funk     = "Funk"
    case hero     = "Hero"
    case morse    = "Morse"
    case sosumi   = "Sosumi"
    case submarine = "Submarine"
    case tink     = "Tink"

    var id: String { rawValue }
    var systemSoundName: NSSound.Name { NSSound.Name(rawValue) }
}

/// Maps notification types to system sounds.
enum SoundEffect: String, CaseIterable, Sendable {
    case success
    case warning
    case question
    case error
    case info

    /// UserDefaults key for this effect's sound choice.
    var defaultsKey: String { "nudge.sound.\(rawValue)" }

    /// Default sound for this effect type.
    var defaultSound: SoundChoice {
        switch self {
        case .success:  return .glass
        case .warning:  return .purr
        case .question: return .ping
        case .error:    return .basso
        case .info:     return .pop
        }
    }

    /// The user's chosen sound (or default).
    var chosenSound: SoundChoice {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let choice = SoundChoice(rawValue: raw) {
            return choice
        }
        return defaultSound
    }
}

/// Plays system sounds for notification events.
final class SoundManager: @unchecked Sendable {
    static let shared = SoundManager()

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "nudge.soundEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "nudge.soundEnabled") }
    }

    var volume: Float {
        get { UserDefaults.standard.float(forKey: "nudge.soundVolume") }
        set { UserDefaults.standard.set(newValue, forKey: "nudge.soundVolume") }
    }

    private let queue = DispatchQueue(label: "com.nudge.sound")

    init() {
        // Register defaults
        UserDefaults.standard.register(defaults: [
            "nudge.soundEnabled": true,
            "nudge.soundVolume": Float(0.5),
        ])
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        let soundName = effect.chosenSound.systemSoundName
        let vol = volume

        queue.async {
            guard let sound = NSSound(named: soundName) else { return }
            sound.volume = vol
            sound.play()
        }
    }

    func playSound(_ choice: SoundChoice) {
        let vol = volume
        queue.async {
            guard let sound = NSSound(named: choice.systemSoundName) else { return }
            sound.volume = vol
            sound.play()
        }
    }

    func playForStyle(_ style: NotificationStyle) {
        switch style {
        case .success:  play(.success)
        case .warning:  play(.warning)
        case .question: play(.question)
        case .error:    play(.error)
        case .info:     play(.info)
        }
    }
}
