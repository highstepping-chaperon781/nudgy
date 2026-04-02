# Integration Test Specifications

## Purpose
Integration tests verify that components work together correctly.
Unlike unit tests (which mock dependencies), integration tests use
real component instances connected to each other.

## Test Environment Setup

```swift
class IntegrationTestBase: XCTestCase {
    var appState: AppState!
    var sessionManager: SessionManager!
    var httpServer: HTTPServer!
    var suppressor: SmartSuppressor!
    var mockFocuser: MockWindowFocuser!
    var tempDir: URL!

    override func setUp() async throws {
        appState = await AppState()
        sessionManager = SessionManager(appState: appState)
        mockFocuser = MockWindowFocuser()
        suppressor = SmartSuppressor(windowFocuser: mockFocuser)

        // Server on random port
        httpServer = HTTPServer(port: 0)
        httpServer.delegate = ... // Connect to sessionManager
        try httpServer.start()

        // Temp directory for hook installer tests
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, ...)
    }

    override func tearDown() {
        httpServer.stop()
        try? FileManager.default.removeItem(at: tempDir)
    }
}
```

## Integration Test Cases

### 1. HTTP → State Pipeline

```
testHTTPToState_StopEvent_SessionBecomesIdle
    1. POST {"hook_event_name": "Stop", "session_id": "s1", "cwd": "/tmp/proj"}
    2. Wait 100ms for processing
    3. Assert: sessionManager.session(for: "s1")?.state == .idle
    4. Assert: appState.sessions contains session with id "s1"

testHTTPToState_PermissionEvent_SessionBecomesWaiting
    1. POST {"hook_event_name": "Notification", "session_id": "s1",
             "matcher": "permission_prompt"}
    2. Wait 100ms
    3. Assert: session state == .waitingPermission
    4. Assert: appState.pendingPermissionCount == 1

testHTTPToState_MultipleEvents_CorrectOrder
    1. POST SessionStart for s1
    2. POST Stop for s1
    3. Wait 100ms
    4. Assert: session state == .idle (not .active)
    5. Assert: session.recentEvents has 2 entries in order
```

### 2. State → Suppression Pipeline

```
testStateToSuppression_FastStop_Suppressed
    1. Create session with startedAt = 2 seconds ago
    2. Process Stop event
    3. Call suppressor.evaluate(event, session)
    4. Assert: decision == .suppress (fast completion)

testStateToSuppression_Permission_AlwaysShows
    1. Mock: mockFocuser.isTerminalFocused = true
    2. Process permission_prompt event
    3. Call suppressor.evaluate(event, session)
    4. Assert: decision == .show (never suppress permissions)

testStateToSuppression_TerminalFocused_InfoSuppressed
    1. Mock: mockFocuser.isTerminalFocused = true
    2. Process Stop event (slow completion, > 5s)
    3. Call suppressor.evaluate(event, session)
    4. Assert: decision == .suppress (terminal focused)
```

### 3. State → Notification → Popup Pipeline

```
testStateToPopup_StopEvent_SuccessPopupCreated
    1. Process Stop event through full pipeline
    2. Assert: appState.notifications contains one item
    3. Assert: notification style == .success
    4. Assert: notification has auto-dismiss set

testStateToPopup_PermissionEvent_WarningPopupCreated
    1. Process permission_prompt through full pipeline
    2. Assert: notification style == .warning
    3. Assert: notification has NO auto-dismiss (persistent)
    4. Assert: notification has Approve/Deny actions
```

### 4. Hook Installer ↔ File System

```
testHookInstaller_ComplexMerge_AllPreserved
    1. Create settings.json with:
       - User hooks on PreToolUse and Stop
       - permissions key with allow rules
       - other custom settings
    2. Run installer.install()
    3. Read settings.json
    4. Assert: user's PreToolUse hooks preserved
    5. Assert: user's Stop hooks preserved AND our Stop hook appended
    6. Assert: permissions key untouched
    7. Assert: our hooks added for Stop, Notification, StopFailure,
              SessionStart, SessionEnd
    8. Run installer.uninstall()
    9. Read settings.json
    10. Assert: user's PreToolUse hooks still there
    11. Assert: user's Stop hooks still there, our Stop hook gone
    12. Assert: permissions key untouched
```

### 5. Full Event Pipeline (End-to-End via HTTP)

```
testFullPipeline_SessionLifecycle
    1. POST SessionStart
    2. Assert: session created, state .active
    3. POST Notification + permission_prompt
    4. Assert: state .waitingPermission, popup shown
    5. POST Stop
    6. Assert: state .idle, success notification
    7. POST SessionEnd
    8. Assert: state .stopped

testFullPipeline_MultiSession
    1. POST SessionStart for s1 and s2
    2. POST Stop for s1
    3. POST permission_prompt for s2
    4. Assert: s1 is .idle, s2 is .waitingPermission
    5. Assert: appState.highestPriorityState == .waitingPermission
    6. Assert: menubar icon reflects permission state
```

### 6. Concurrency Stress Test

```
testConcurrency_50ParallelEvents_AllProcessed
    1. Launch 50 concurrent HTTP POST requests, each with unique session ID
    2. Wait for all to complete
    3. Assert: all 50 sessions exist in sessionManager
    4. Assert: no duplicate sessions
    5. Assert: no thread sanitizer warnings
```

## Timing & Reliability

- All async assertions use XCTestExpectation with 5-second timeout
- Polling interval for state checks: 50ms
- Tests that depend on timing use generous margins (2x expected duration)
- No `sleep()` calls — use expectations and fulfillment
