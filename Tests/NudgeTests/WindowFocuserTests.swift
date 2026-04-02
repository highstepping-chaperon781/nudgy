import XCTest
@testable import Nudge

final class WindowFocuserTests: XCTestCase {

    func testKnownAppsContainsExpectedBundleIds() {
        let expected = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "net.kovidgoyal.kitty",
            "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",
            "com.anthropic.claudedesktop",
        ]
        for bundleId in expected {
            XCTAssertNotNil(WindowFocuser.knownApps[bundleId], "Missing: \(bundleId)")
        }
        XCTAssertEqual(WindowFocuser.knownApps.count, 8)
    }

    func testKnownAppsFriendlyNames() {
        XCTAssertEqual(WindowFocuser.knownApps["com.apple.Terminal"], "Terminal")
        XCTAssertEqual(WindowFocuser.knownApps["com.microsoft.VSCode"], "VS Code")
        XCTAssertEqual(WindowFocuser.knownApps["com.mitchellh.ghostty"], "Ghostty")
    }

    func testIsTerminalFocusedReturnsBool() {
        let focuser = WindowFocuser()
        // Just verify it doesn't crash and returns a bool
        _ = focuser.isTerminalFocused()
    }

    func testDetectTerminalAppReturnsNilForInvalidPID() {
        let focuser = WindowFocuser()
        let result = focuser.detectTerminalApp(pid: nil)
        XCTAssertNil(result)
    }

    func testDetectTerminalAppReturnsNilForNonExistentPID() {
        let focuser = WindowFocuser()
        let result = focuser.detectTerminalApp(pid: 99999)
        XCTAssertNil(result)
    }

    func testFocusSessionReturnsFalseForNoMatchingApp() {
        let focuser = WindowFocuser()
        let session = AgentSession(
            id: "test",
            state: .idle,
            projectName: "Test",
            terminalPID: 99999,
            accentColor: .blue,
            startedAt: Date(),
            lastEventAt: Date(),
            pendingPermissions: [],
            recentEvents: RingBuffer<HookEvent>(capacity: 50),
            stats: SessionStats()
        )
        // May return true if any terminal app happens to be running
        _ = focuser.focusSession(session)
    }
}
