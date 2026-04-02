# Agent 01: Project Setup & Scaffolding

## Objective
Create the Swift Package Manager project structure, configure build targets,
and establish the file organization that all other agents will work within.

## Scope
- Swift Package (Package.swift)
- App entry point
- Info.plist equivalent configuration
- Directory structure
- .gitignore
- Xcode project generation (optional)

## Dependencies
- None (this agent runs first)

## Deliverables

### 1. Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nudge",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Nudge",
            dependencies: [],
            path: "Sources/Nudge",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NudgeTests",
            dependencies: ["Nudge"],
            path: "Tests/NudgeTests"
        ),
    ]
)
```

### 2. Directory Structure

```
Nudge/
├── Package.swift
├── .gitignore
├── README.md
├── Sources/
│   └── Nudge/
│       ├── App/
│       │   ├── NudgeApp.swift    # @main entry, NSApplication setup
│       │   └── AppDelegate.swift          # NSApplicationDelegate
│       ├── Models/
│       │   ├── HookEvent.swift            # Agent 03
│       │   ├── AgentSession.swift        # Agent 03
│       │   ├── AppState.swift             # Agent 03
│       │   └── AnyCodable.swift           # Agent 03
│       ├── Server/
│       │   └── HTTPServer.swift           # Agent 02
│       ├── UI/
│       │   ├── PopupWindowController.swift  # Agent 04
│       │   ├── PopupContentView.swift       # Agent 04
│       │   ├── MenuBarManager.swift         # Agent 05
│       │   ├── MenuBarView.swift            # Agent 05
│       │   └── SettingsView.swift           # Agent 10
│       ├── Services/
│       │   ├── SessionManager.swift         # Agent 03
│       │   ├── SoundManager.swift           # Agent 06
│       │   ├── WindowFocuser.swift          # Agent 07
│       │   ├── HookInstaller.swift          # Agent 08
│       │   └── SmartSuppressor.swift        # Agent 09
│       └── Resources/
│           └── (placeholder for future assets)
└── Tests/
    └── NudgeTests/
        ├── HTTPServerTests.swift          # Agent 02
        ├── SessionManagerTests.swift      # Agent 03
        ├── HookEventTests.swift           # Agent 03
        ├── PopupWindowTests.swift         # Agent 04
        ├── SoundManagerTests.swift        # Agent 06
        ├── HookInstallerTests.swift       # Agent 08
        ├── SmartSuppressorTests.swift     # Agent 09
        └── IntegrationTests.swift         # Agent 11
```

### 3. App Entry Point (NudgeApp.swift)

Skeleton that other agents will flesh out:

```swift
import Cocoa

@main
struct NudgeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)  // No dock icon
        app.run()
    }
}
```

### 4. AppDelegate.swift (skeleton)

```swift
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    // Components initialized by their respective agents
    // var httpServer: HTTPServer!
    // var menuBarManager: MenuBarManager!
    // var popupManager: PopupWindowController!
    // var sessionManager: SessionManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Each agent adds its initialization here
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}
```

### 5. .gitignore

```
.DS_Store
/.build
/Packages
xcuserdata/
DerivedData/
.swiftpm/
*.xcodeproj
Package.resolved
```

## Self-Verification

1. Run `swift build` — must compile with zero errors and zero warnings
2. Run `swift test` — no tests yet, but test target must be resolvable
3. Verify directory structure matches the specification above
4. Verify `NSApp.setActivationPolicy(.accessory)` is set (no dock icon)

## Notes for Review Agent
- This agent creates SKELETON files. Other agents will fill them in.
- The App entry point uses manual NSApplication setup, not SwiftUI App protocol,
  because we need NSPanel management that SwiftUI App doesn't support well.
- No external dependencies in Package.swift — intentional. Sparkle will be
  added by Agent 12 (Distribution) later.
