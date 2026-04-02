# Data Models & State Management

## Core Models

### HookEvent (incoming from AI coding agent)

```swift
struct HookEvent: Codable, Identifiable {
    let id: UUID = UUID()
    let hookEventName: String       // "Stop", "Notification", "StopFailure", etc.
    let sessionId: String?
    let cwd: String?
    let permissionMode: String?
    let timestamp: Date = Date()

    // Notification-specific
    let matcher: String?            // "permission_prompt", "idle_prompt", etc.

    // Tool-use specific
    let toolName: String?
    let toolInput: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case cwd
        case permissionMode = "permission_mode"
        case matcher
        case toolName = "tool_name"
        case toolInput = "tool_input"
    }
}
```

### AgentSession

```swift
struct AgentSession: Identifiable {
    let id: String                          // session_id from hook
    var state: SessionState
    var projectName: String                 // Derived from cwd basename
    var workingDirectory: String?
    var terminalApp: String?                // "Terminal", "iTerm2", "VS Code"
    var terminalPID: pid_t?
    var accentColor: Color                  // Auto-assigned for visual distinction
    var startedAt: Date
    var lastEventAt: Date
    var pendingPermissions: [PermissionRequest]
    var recentEvents: RingBuffer<HookEvent> // Last 50 events
    var stats: SessionStats
}
```

### SessionState

```swift
enum SessionState: String, CaseIterable {
    case active             // Session started, Claude is generating
    case idle               // Claude finished, waiting for next prompt
    case waitingPermission  // Blocked on permission approval
    case waitingInput       // Claude asked a question
    case error              // StopFailure or repeated errors
    case stopped            // Session ended

    var priority: Int {
        switch self {
        case .waitingPermission: return 100  // Highest
        case .error:             return 90
        case .waitingInput:      return 80
        case .active:            return 50
        case .idle:              return 10
        case .stopped:           return 0    // Lowest
        }
    }
}
```

### PermissionRequest

```swift
struct PermissionRequest: Identifiable {
    let id: UUID = UUID()
    let sessionId: String
    let toolName: String
    let command: String?                // For Bash tool: the command string
    let filePath: String?              // For Edit/Write: the file path
    let timestamp: Date
    var isResolved: Bool = false
}
```

### SessionStats

```swift
struct SessionStats {
    var eventCount: Int = 0
    var permissionCount: Int = 0
    var errorCount: Int = 0
    var totalDuration: TimeInterval = 0
}
```

### NotificationItem (UI layer)

```swift
struct NotificationItem: Identifiable {
    let id: UUID = UUID()
    let sessionId: String
    let projectName: String
    let title: String
    let message: String
    let style: NotificationStyle
    let timestamp: Date
    var autoDismissAfter: TimeInterval?  // nil = persistent
    var actions: [NotificationAction]
}

enum NotificationStyle {
    case success    // Green — Claude finished
    case warning    // Amber — permission needed
    case question   // Blue — Claude asking something
    case error      // Red — something failed
    case info       // Gray — informational

    var color: Color { ... }
    var icon: String { ... }  // SF Symbol name
    var sound: SoundEffect? { ... }
}

struct NotificationAction {
    let label: String
    let style: ActionStyle     // .primary, .secondary, .destructive
    let handler: () -> Void
}
```

## State Flow

```
HTTP POST arrives
    │
    ▼
HTTPServer.receive()
    │ Deserialize JSON → HookEvent
    ▼
SessionManager.handleEvent(event)
    │ Update or create AgentSession
    │ Map hook_event_name to SessionState:
    │   "Stop"                        → .idle
    │   "Notification" + permission   → .waitingPermission
    │   "Notification" + idle_prompt  → .waitingInput
    │   "StopFailure"                 → .error
    │   "SessionStart"                → .active
    │   "SessionEnd"                  → .stopped
    ▼
SmartSuppressor.shouldNotify(event, session)
    │ Apply suppression rules
    │ Returns: .show / .suppress / .batch
    ▼
if .show:
    AppState.addNotification(item)
        │
        ├──► PopupManager.show(item)      // Floating window
        ├──► MenuBarManager.update(state)  // Icon + badge
        └──► SoundManager.play(style)      // Audio feedback
```

## Persistence

### UserDefaults Keys
```
nudgy.port              Int     (default: 9847)
nudgy.soundEnabled      Bool    (default: true)
nudgy.soundVolume       Float   (default: 0.5)
nudgy.suppressThreshold Double  (default: 5.0 seconds)
nudgy.autoDismissDelay  Double  (default: 6.0 seconds)
nudgy.popupPosition     String  (default: "topRight")
nudgy.launchAtLogin     Bool    (default: false)
nudgy.showInAllSpaces   Bool    (default: true)
```

### Keychain
```
com.nudgy.sharedSecret  String  (random 32-byte token, hex-encoded)
```

### File System
```
~/.claude/settings.json         Hooks configuration (read/write by HookInstaller)
~/.claude/settings.json.backup.* Timestamped backups before modification
```

## RingBuffer Utility

```swift
struct RingBuffer<T> {
    private var storage: [T] = []
    private let capacity: Int

    init(capacity: Int = 50) {
        self.capacity = capacity
    }

    mutating func append(_ element: T) {
        storage.append(element)
        if storage.count > capacity {
            storage.removeFirst()
        }
    }

    var elements: [T] { storage }
    var count: Int { storage.count }
}
```

## AnyCodable Utility

A type-erased Codable wrapper for flexible JSON payloads (tool_input varies
by tool type). Use a lightweight implementation — ~50 lines supporting
String, Int, Double, Bool, Array, Dictionary, and nil.
