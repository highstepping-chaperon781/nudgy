# Agent 10: Settings & Preferences

## Objective
Implement the Settings window (macOS Preferences pattern) with all
configurable options, persisted via UserDefaults. Also handle first-run
onboarding and launch-at-login.

## Scope
- SwiftUI Settings window
- General tab: port, launch at login, popup position
- Notifications tab: sound on/off, volume, suppression thresholds, auto-dismiss
- About tab: version, links, hook status
- UserDefaults persistence
- First-run onboarding flow
- Launch at login (SMAppService)
- Permission status display (Accessibility, Screen Recording)

## Dependencies
- Agent 04: PopupWindowController (popup position enum)
- Agent 05: MenuBarManager (settings link)
- Agent 06: SoundManager (sound enabled, volume)
- Agent 09: SmartSuppressor (thresholds)

## Files to Create

### Sources/Nudge/UI/SettingsView.swift

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NotificationSettingsTab(appState: appState)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AboutTab(appState: appState)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 320)
    }
}

struct GeneralSettingsTab: View {
    @Bindable var appState: AppState
    @AppStorage("nudge.port") var port: Int = 9847
    @AppStorage("nudge.launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("nudge.popupPosition") var popupPosition: String = "topRight"

    var body: some View {
        Form {
            Section("Server") {
                TextField("Port", value: $port, format: .number)
                    .frame(width: 80)
                Text("Restart required after changing port")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Section("Popup Position") {
                Picker("Position", selection: $popupPosition) {
                    Text("Top Right").tag("topRight")
                    Text("Top Left").tag("topLeft")
                    Text("Bottom Right").tag("bottomRight")
                    Text("Bottom Left").tag("bottomLeft")
                }
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if AXIsProcessTrusted() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Granted")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Button("Grant...") {
                            openAccessibilitySettings()
                        }
                    }
                }
                Text("Required for focusing specific terminal windows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security"
            + "?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }
}

struct NotificationSettingsTab: View {
    @AppStorage("nudge.soundEnabled") var soundEnabled: Bool = true
    @AppStorage("nudge.soundVolume") var soundVolume: Double = 0.5
    @AppStorage("nudge.autoDismissDelay") var autoDismiss: Double = 6.0
    @AppStorage("nudge.suppressThreshold") var suppressThreshold: Double = 5.0
    @AppStorage("nudge.showInAllSpaces") var showInAllSpaces: Bool = true

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Play sounds", isOn: $soundEnabled)
                if soundEnabled {
                    Slider(value: $soundVolume, in: 0...1) {
                        Text("Volume")
                    }
                    Button("Test Sound") {
                        SoundManager.shared.play(.success)
                    }
                }
            }

            Section("Popup Behavior") {
                Slider(value: $autoDismiss, in: 2...30, step: 1) {
                    Text("Auto-dismiss: \(Int(autoDismiss))s")
                }
                Toggle("Show on all Spaces", isOn: $showInAllSpaces)
            }

            Section("Smart Suppression") {
                Slider(value: $suppressThreshold, in: 1...15, step: 1) {
                    Text("Fast completion threshold: \(Int(suppressThreshold))s")
                }
                Text("Notifications are suppressed for tasks that\ncomplete faster than this threshold")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutTab: View {
    let appState: AppState

    var body: some View {
        Form {
            Section("Nudge") {
                LabeledContent("Version", value: Bundle.main.shortVersion)
                LabeledContent("Server", value: appState.isServerRunning
                    ? "Running on port \(appState.port)"
                    : "Stopped"
                )
                LabeledContent("Active Sessions",
                    value: "\(appState.activeSessionCount)"
                )
            }

            Section("Hooks") {
                let installer = HookInstaller(port: appState.port)
                LabeledContent("Status", value: installer.isInstalled()
                    ? "Installed"
                    : "Not installed"
                )
                HStack {
                    Button("Install Hooks") {
                        try? installer.install()
                    }
                    Button("Uninstall Hooks") {
                        try? installer.uninstall()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

### First-Run Onboarding

On first launch (detected via `@AppStorage("nudge.hasLaunched")`):

1. Show a welcome window explaining what Nudge does
2. Install hooks automatically (with user confirmation)
3. Request Notification permission
4. Suggest granting Accessibility permission
5. Show a test notification to confirm everything works
6. Set `hasLaunched = true`

### Bundle Extension

```swift
extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
```

## Tests to Write

```
testDefaultSettingsValues
    → Verify all @AppStorage defaults are correct

testLaunchAtLoginToggle
    → Toggle on → SMAppService.mainApp.register called
    → Toggle off → .unregister called

testPortChangeRequiresRestart
    → Change port → verify server is NOT automatically restarted

testSoundVolumeAppliedToManager
    → Change soundVolume → SoundManager.shared.volume matches

testSuppressThresholdAppliedToSuppressor
    → Change threshold → SmartSuppressor uses new value
```

## Self-Verification

1. `swift build` compiles
2. All tests pass
3. Settings window opens from menubar dropdown
4. Changes persist across app restarts (UserDefaults)
5. Launch at login works (SMAppService)
6. Accessibility permission check is correct
