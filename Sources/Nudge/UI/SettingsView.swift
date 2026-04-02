import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NotificationSettingsTab()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AboutTab(appState: appState)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 340)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @AppStorage("nudge.port") private var port: Int = 9847
    @AppStorage("nudge.launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("nudge.popupPosition") private var popupPosition: String = "topRight"

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
                            .foregroundStyle(.secondary)
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
            NSLog("Nudge: Launch at login error: \(error)")
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Notifications Tab

struct NotificationSettingsTab: View {
    @AppStorage("nudge.soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("nudge.soundVolume") private var soundVolume: Double = 0.5
    @AppStorage("nudge.autoDismissDelay") private var autoDismiss: Double = 6.0
    @AppStorage("nudge.popupPreset") private var popupPreset: String = PopupPreset.minimal.rawValue

    private var sampleItem: NotificationItem {
        NotificationItem(
            sessionId: "preview",
            projectName: "my-app",
            title: "Done",
            message: "Finished working",
            style: .success,
            autoDismissAfter: nil
        )
    }

    var body: some View {
        Form {
            Section("Popup Style") {
                Picker("Style", selection: $popupPreset) {
                    ForEach(PopupPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                // Live preview
                let activePreset = PopupPreset(rawValue: popupPreset) ?? .minimal
                Text(activePreset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    PopupContentView(
                        item: sampleItem,
                        onDismiss: {},
                        onAction: { _ in },
                        preset: activePreset
                    )
                    .scaleEffect(0.9)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Sound") {
                Toggle("Play sounds", isOn: $soundEnabled)
                if soundEnabled {
                    Slider(value: $soundVolume, in: 0...1) {
                        Text("Volume")
                    }

                    ForEach(SoundEffect.allCases, id: \.rawValue) { effect in
                        SoundPicker(effect: effect)
                    }
                }
            }

            Section("Behavior") {
                Slider(value: $autoDismiss, in: 2...30, step: 1) {
                    Text("Auto-dismiss: \(Int(autoDismiss))s")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

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

            Section("Logs") {
                LabeledContent("Path", value: NudgeLogger.shared.logFilePath)
                    .textSelection(.enabled)
                Button("Open in Finder") {
                    NSWorkspace.shared.selectFile(
                        NudgeLogger.shared.logFilePath,
                        inFileViewerRootedAtPath: ""
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Sound Picker

struct SoundPicker: View {
    let effect: SoundEffect
    @AppStorage private var chosen: String

    init(effect: SoundEffect) {
        self.effect = effect
        self._chosen = AppStorage(wrappedValue: effect.defaultSound.rawValue, effect.defaultsKey)
    }

    var body: some View {
        HStack {
            Text(effect.rawValue.capitalized)
                .font(.system(size: 11))
                .frame(width: 60, alignment: .leading)

            Picker("", selection: $chosen) {
                ForEach(SoundChoice.allCases) { sound in
                    Text(sound.rawValue).tag(sound.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 100)

            Button {
                if let choice = SoundChoice(rawValue: chosen) {
                    SoundManager.shared.playSound(choice)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
