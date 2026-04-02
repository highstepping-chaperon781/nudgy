# Agent 03: Data Models & State Engine

## Objective
Implement all core data models, the SessionManager actor for thread-safe
session tracking, and the AppState observable for driving SwiftUI UI.

## Scope
- HookEvent model (Codable, from JSON)
- AgentSession model
- SessionState enum
- PermissionRequest model
- NotificationItem model
- SessionManager actor
- AppState @Observable class
- AnyCodable utility
- RingBuffer utility

## Dependencies
- Agent 01: Project structure exists

## Files to Create

### Sources/Nudge/Models/HookEvent.swift
- Codable struct matching the JSON schema from IPC_PROTOCOL.md
- CodingKeys with snake_case → camelCase mapping
- Auto-generated UUID id for Identifiable conformance
- Timestamp defaults to Date() on creation

### Sources/Nudge/Models/AgentSession.swift
- Session struct with all fields per DATA_MODELS.md
- SessionState enum with priority ordering
- PermissionRequest struct
- SessionStats struct
- Computed properties:
  - `isActionRequired: Bool` (waitingPermission or waitingInput)
  - `displayName: String` (project name or session ID truncated)
  - `duration: TimeInterval` (since startedAt)

### Sources/Nudge/Models/AppState.swift
```swift
@MainActor
@Observable
final class AppState {
    var sessions: [AgentSession] = []
    var notifications: [NotificationItem] = []
    var isServerRunning: Bool = false
    var port: UInt16 = 9847

    // Computed
    var activeSessionCount: Int { ... }
    var highestPriorityState: SessionState { ... }
    var pendingPermissionCount: Int { ... }

    // Menubar icon state
    var statusIcon: String { ... }       // SF Symbol name
    var iconColor: Color { ... }         // Based on highest priority

    func addNotification(_ item: NotificationItem) { ... }
    func removeNotification(id: UUID) { ... }
    func updateFromSession(_ session: AgentSession) { ... }
}
```

### Sources/Nudge/Services/SessionManager.swift
```swift
actor SessionManager {
    private var sessions: [String: AgentSession] = [:]
    private let appState: AppState
    private var cleanupTask: Task<Void, Never>?

    init(appState: AppState) { ... }

    // Core event processing
    func handleEvent(_ event: HookEvent) async { ... }

    // Session lifecycle
    func session(for id: String) -> AgentSession? { ... }
    func activeSessions() -> [AgentSession] { ... }
    func removeSession(id: String) { ... }

    // Stale session cleanup (runs every 60s)
    func startCleanupTimer() { ... }
    func cleanupStaleSessions() { ... }

    // Persistence for crash recovery
    func persistToDisk() { ... }
    func restoreFromDisk() { ... }
}
```

### Key Logic: Event → State Mapping

```swift
func handleEvent(_ event: HookEvent) async {
    let sessionId = event.sessionId ?? "unknown"

    var session = sessions[sessionId] ?? AgentSession(
        id: sessionId,
        state: .active,
        projectName: projectName(from: event.cwd),
        workingDirectory: event.cwd,
        startedAt: Date(),
        lastEventAt: Date(),
        accentColor: nextAccentColor()
    )

    switch event.hookEventName {
    case "SessionStart":
        session.state = .active

    case "Stop":
        session.state = .idle

    case "Notification":
        switch event.matcher {
        case "permission_prompt":
            session.state = .waitingPermission
            session.pendingPermissions.append(
                PermissionRequest(from: event)
            )
        case "idle_prompt":
            session.state = .waitingInput
        default:
            break
        }

    case "StopFailure":
        session.state = .error

    case "SessionEnd":
        session.state = .stopped

    default:
        break
    }

    session.lastEventAt = Date()
    session.recentEvents.append(event)
    session.stats.eventCount += 1
    sessions[sessionId] = session

    // Update UI on main thread
    await MainActor.run {
        appState.updateFromSession(session)
    }
}
```

### Sources/Nudge/Models/AnyCodable.swift
- Lightweight type-erased Codable wrapper
- Supports: String, Int, Double, Bool, [AnyCodable], [String: AnyCodable], nil
- ~60 lines of code

### Sources/Nudge/Models/RingBuffer.swift
- Generic ring buffer with configurable capacity (default 50)
- `append(_:)`, `elements`, `count`, `last`

## Tests to Write

### Tests/NudgeTests/HookEventTests.swift
```
testDecodeStopEvent
testDecodeNotificationPermissionPrompt
testDecodeNotificationIdlePrompt
testDecodeStopFailure
testDecodeSessionStart
testDecodeSessionEnd
testDecodeWithMissingOptionalFields
testDecodeWithUnknownEventName
testDecodeInvalidJSON            // Should throw
```

### Tests/NudgeTests/SessionManagerTests.swift
```
testCreateSessionOnFirstEvent
testUpdateSessionStateOnStop
testUpdateSessionStateOnPermission
testUpdateSessionStateOnIdlePrompt
testUpdateSessionStateOnError
testUpdateSessionStateOnSessionEnd
testMultipleSessionsTrackedIndependently
testStaleSessionCleanup
testProjectNameDerivedFromCwd
testEventHistoryRingBuffer
testSessionStatsIncrement
testConcurrentEventProcessing    // Send 100 events from multiple tasks
testPersistAndRestore
```

### Tests/NudgeTests/AppStateTests.swift
```
testHighestPriorityState
testActiveSessionCount
testPendingPermissionCount
testStatusIconReflectsState
testNotificationAddAndRemove
```

## Self-Verification

1. `swift build` compiles with no errors
2. All tests pass (expect 15+ tests)
3. JSON decoding matches all payloads in IPC_PROTOCOL.md exactly
4. SessionManager correctly maps every event type to the right state
5. Concurrent access to SessionManager does not deadlock or race
6. RingBuffer maintains capacity limit under rapid appends

## Thread Safety Guarantee
- `SessionManager` is a Swift `actor` — the compiler enforces isolation
- `AppState` is `@MainActor` — only accessed from the main thread
- Communication between them uses `await MainActor.run { ... }`
- No manual locks, no DispatchQueues for state — pure Swift concurrency
