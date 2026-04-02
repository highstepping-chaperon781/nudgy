# Agent 06: Sound System

## Objective
Implement sound playback for notification events using macOS system sounds,
with volume control and Focus mode respect.

## Scope
- Sound effect enum mapped to system sounds
- Volume control (independent of system volume)
- Play sound for each notification style
- Respect macOS Do Not Disturb / Focus modes
- Enable/disable toggle
- Thread-safe playback

## Dependencies
- Agent 01: Project structure

## Files to Create

### Sources/Nudge/Services/SoundManager.swift

```swift
import AppKit
import AVFoundation

enum SoundEffect: String, CaseIterable {
    case success  = "Glass"
    case warning  = "Purr"
    case question = "Ping"
    case error    = "Basso"
    case info     = "Pop"

    var systemSoundName: NSSound.Name {
        NSSound.Name(rawValue)
    }
}

final class SoundManager {
    static let shared = SoundManager()

    var isEnabled: Bool = true
    var volume: Float = 0.5  // 0.0 to 1.0

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        guard !isDoNotDisturbActive() else { return }

        guard let sound = NSSound(named: effect.systemSoundName) else {
            return
        }
        sound.volume = volume
        sound.play()
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

    // MARK: - Private

    private func isDoNotDisturbActive() -> Bool {
        // Check macOS Focus/DND state
        // Use DistributedNotificationCenter or
        // read com.apple.controlcenter DoNotDisturb key
        // Return true if DND is active → suppress sound
        return false // TODO: implement
    }
}
```

### DND Detection

```swift
private func isDoNotDisturbActive() -> Bool {
    // macOS 12+: Check the Focus state
    let store = CBCentralManager() // Not this — use:
    // Read: defaults read com.apple.controlcenter "NSStatusItem Visible FocusModes"
    // Or observe: com.apple.doNotDisturb.stateChanged distributed notification

    // Pragmatic approach: check assertion state
    let result = Process()
    result.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    result.arguments = [
        "read", "com.apple.controlcenter",
        "NSStatusItem Visible FocusModes"
    ]
    // Parse output to determine DND state
    // This is imperfect — revisit if needed
    return false
}
```

## Tests to Write

### Tests/NudgeTests/SoundManagerTests.swift

```
testPlaySuccessSound
    → Call play(.success), verify no crash

testPlayAllSounds
    → Iterate SoundEffect.allCases, play each, verify no crash

testSoundDisabledDoesNotPlay
    → isEnabled = false, play → verify NSSound was not initialized

testVolumeApplied
    → Set volume to 0.3, play → verify sound.volume == 0.3

testPlayForStyleMapping
    → Each NotificationStyle maps to the correct SoundEffect

testThreadSafety
    → Play 10 sounds concurrently from different threads → no crash
```

## Self-Verification

1. `swift build` compiles
2. All tests pass
3. Each system sound exists on macOS (Glass, Purr, Ping, Basso, Pop)
4. Volume control works (sound is quieter at 0.2 than at 1.0)
