# Agent 11: Integration & E2E Testing

## Objective
Write comprehensive integration tests that verify the full event flow:
HTTP request → state update → notification display → sound playback.
Also write E2E tests that simulate real AI coding agent hook scenarios.

## Scope
- Integration tests: component interactions
- E2E tests: full round-trip from HTTP POST to popup
- Performance tests: latency, memory, concurrency
- Stress tests: rapid events, many sessions
- Regression tests: known edge cases

## Dependencies
- ALL agents 01-10 must be complete

## Files to Create

### Tests/NudgeTests/IntegrationTests.swift

```swift
import XCTest
@testable import Nudge

final class IntegrationTests: XCTestCase {

    var appState: AppState!
    var sessionManager: SessionManager!
    var httpServer: HTTPServer!
    var popupController: PopupWindowController!
    var soundManager: SoundManager!
    var suppressor: SmartSuppressor!

    override func setUp() async throws {
        appState = AppState()
        sessionManager = SessionManager(appState: appState)
        // Start server on random available port
        httpServer = HTTPServer(port: 0)  // 0 = OS assigns port
        popupController = PopupWindowController()
        soundManager = SoundManager.shared
        soundManager.isEnabled = false  // Don't play sounds in tests
        suppressor = SmartSuppressor(windowFocuser: WindowFocuser())
    }

    override func tearDown() {
        httpServer.stop()
    }

    // --- Full Round-Trip Tests ---

    func testStopEventShowsSuccessPopup() async throws {
        // POST a Stop event to HTTP server
        // Verify: session state becomes .idle
        // Verify: notification is created with .success style
        // Verify: popup panel is visible
    }

    func testPermissionEventShowsWarningPopup() async throws {
        // POST a Notification event with matcher=permission_prompt
        // Verify: session state becomes .waitingPermission
        // Verify: notification is created with .warning style
        // Verify: popup is persistent (no auto-dismiss)
    }

    func testIdlePromptEventShowsQuestionPopup() async throws {
        // POST a Notification event with matcher=idle_prompt
        // Verify: session state becomes .waitingInput
        // Verify: notification is created with .question style
    }

    func testStopFailureEventShowsErrorPopup() async throws {
        // POST a StopFailure event
        // Verify: session state becomes .error
        // Verify: notification is created with .error style
    }

    func testSessionStartCreatesSession() async throws {
        // POST SessionStart event
        // Verify: new session appears in appState.sessions
        // Verify: session state is .active
    }

    func testSessionEndRemovesSession() async throws {
        // POST SessionStart, then SessionEnd
        // Verify: session state is .stopped
    }

    // --- Multi-Session Tests ---

    func testMultipleSessionsTrackedIndependently() async throws {
        // POST events for session-A and session-B
        // Verify: appState.sessions has 2 entries
        // Verify: each has correct state
    }

    func testMultipleSessionsDifferentStates() async throws {
        // Session A: Stop (idle)
        // Session B: permission_prompt (waiting)
        // Verify: menubar icon reflects permission (higher priority)
    }

    // --- Suppression Integration Tests ---

    func testFastCompletionSuppressed() async throws {
        // POST SessionStart, then Stop 2 seconds later
        // Verify: suppressor returns .suppress
        // Verify: no popup shown
    }

    func testSlowCompletionNotSuppressed() async throws {
        // POST SessionStart, wait 6 seconds, then Stop
        // Verify: suppressor returns .show
        // Verify: popup shown
    }

    func testPermissionNeverSuppressed() async throws {
        // Even when terminal is "focused" (mocked)
        // POST permission_prompt → popup always shown
    }

    // --- Hook Installer Integration ---

    func testHookInstallAndVerify() throws {
        // Use temp directory
        let installer = HookInstaller(port: 9847, settingsDir: tempDir)
        try installer.install()
        XCTAssertTrue(installer.isInstalled())
        XCTAssertTrue(installer.verify())
    }

    func testHookInstallUninstallRoundTrip() throws {
        let installer = HookInstaller(port: 9847, settingsDir: tempDir)

        // Write existing user hooks
        let existing = """
        {
            "hooks": {
                "PreToolUse": [
                    {"hooks": [{"type": "command", "command": "echo hi"}]}
                ]
            },
            "permissions": {"allow": ["Read"]}
        }
        """
        try existing.write(to: tempSettingsPath, atomically: true, encoding: .utf8)

        // Install
        try installer.install()

        // Verify user hooks preserved
        let after = try JSONSerialization.jsonObject(
            with: Data(contentsOf: tempSettingsPath)
        ) as! [String: Any]
        let hooks = after["hooks"] as! [String: Any]
        XCTAssertNotNil(hooks["PreToolUse"])  // User hook preserved
        XCTAssertNotNil(hooks["Stop"])         // Our hook added
        XCTAssertNotNil(after["permissions"])  // Non-hook settings preserved

        // Uninstall
        try installer.uninstall()

        // Verify user hooks still there
        let afterUninstall = try JSONSerialization.jsonObject(
            with: Data(contentsOf: tempSettingsPath)
        ) as! [String: Any]
        let hooksAfter = afterUninstall["hooks"] as! [String: Any]
        XCTAssertNotNil(hooksAfter["PreToolUse"])  // User hook still there
        XCTAssertNil(hooksAfter["Stop"])            // Our hook gone
    }
}
```

### Tests/NudgeTests/E2ETests.swift

```swift
final class E2ETests: XCTestCase {

    /// Simulate a real AI coding agent session lifecycle
    func testFullSessionLifecycle() async throws {
        // 1. SessionStart → session appears
        // 2. Multiple tool uses → session stays .active
        // 3. Notification(permission_prompt) → popup appears
        // 4. (User approves) → session continues
        // 5. Stop → success popup, session becomes .idle
        // 6. SessionEnd → session marked .stopped
    }

    /// Simulate two sessions running in parallel
    func testParallelSessions() async throws {
        // Session A: starts, works, finishes
        // Session B: starts, hits permission, waits
        // Verify: both tracked, B's permission popup visible,
        //         A's completion doesn't dismiss B's popup
    }

    /// Simulate AI coding agent crash (no SessionEnd)
    func testStaleSessionCleanup() async throws {
        // 1. SessionStart
        // 2. No events for 6 minutes
        // 3. Verify: session marked as stale/stopped by cleanup timer
    }

    /// Simulate rapid-fire events (e.g., Claude reading many files)
    func testRapidFireEventBatching() async throws {
        // Send 10 Stop events in 5 seconds
        // Verify: only 1-2 notifications shown (batched)
    }

    /// Simulate permission waiting escalation
    func testPermissionEscalation() async throws {
        // 1. permission_prompt arrives
        // 2. Wait 30s → notification stays
        // 3. Wait 2min → escalation triggers (sound replays)
    }
}
```

### Tests/NudgeTests/PerformanceTests.swift

```swift
final class PerformanceTests: XCTestCase {

    func testEventProcessingLatency() throws {
        // Measure time from HTTP receive to notification creation
        // Target: < 50ms p99
        measure {
            // Send 100 events, measure average processing time
        }
    }

    func testMemoryUnderLoad() throws {
        // Create 20 sessions, send 1000 events total
        // Verify: memory stays under 50MB
    }

    func testConcurrent50Sessions() async throws {
        // Create 50 sessions simultaneously
        // Send events to all of them concurrently
        // Verify: no deadlocks, no crashes, all events processed
    }

    func testServerThroughput() throws {
        // Send 1000 HTTP requests in 10 seconds
        // Verify: all 1000 get 200 OK responses
        // Verify: server doesn't drop connections
    }

    func testPopupCreationPerformance() throws {
        // Create and destroy 100 popup panels
        // Verify: no memory leaks (panel count returns to 0)
        // Verify: total time < 5 seconds
    }
}
```

## Test Helpers

### MockWindowFocuser

```swift
class MockWindowFocuser: WindowFocuser {
    var mockIsTerminalFocused: Bool = false

    override func isTerminalFocused() -> Bool {
        return mockIsTerminalFocused
    }
}
```

### HTTP Test Client

```swift
func sendEvent(
    port: UInt16,
    eventName: String,
    sessionId: String = "test-session",
    matcher: String? = nil,
    cwd: String = "/tmp/test"
) async throws -> Int {
    var body: [String: Any] = [
        "hook_event_name": eventName,
        "session_id": sessionId,
        "cwd": cwd,
    ]
    if let matcher = matcher {
        body["matcher"] = matcher
    }

    var request = URLRequest(
        url: URL(string: "http://127.0.0.1:\(port)/event")!
    )
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (_, response) = try await URLSession.shared.data(for: request)
    return (response as! HTTPURLResponse).statusCode
}
```

## Self-Verification

1. `swift test` runs ALL tests (unit + integration + E2E + performance)
2. 100% of integration tests pass
3. 100% of E2E scenario tests pass
4. Performance tests meet targets:
   - Event latency < 50ms p99
   - Memory < 50MB under load
   - Server handles 100 req/s
5. No memory leaks detected
6. No thread sanitizer warnings (enable with `-sanitize=thread`)

## CI Configuration

```yaml
# Run with thread sanitizer
swift test --sanitize=thread

# Run with address sanitizer
swift test --sanitize=address

# Run performance tests separately (they take longer)
swift test --filter PerformanceTests
```
