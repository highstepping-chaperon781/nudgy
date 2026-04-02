import XCTest
import SwiftUI
@testable import Nudge

final class AppStateTests: XCTestCase {

    @MainActor
    func testHighestPriorityState() {
        let state = AppState()
        state.sessions = [
            makeSession(id: "s1", state: .idle),
            makeSession(id: "s2", state: .waitingPermission),
            makeSession(id: "s3", state: .active),
        ]
        XCTAssertEqual(state.highestPriorityState, .waitingPermission)
    }

    @MainActor
    func testHighestPriorityStateExcludesStopped() {
        let state = AppState()
        state.sessions = [
            makeSession(id: "s1", state: .stopped),
            makeSession(id: "s2", state: .idle),
        ]
        XCTAssertEqual(state.highestPriorityState, .idle)
    }

    @MainActor
    func testHighestPriorityStateDefaultsToIdle() {
        let state = AppState()
        XCTAssertEqual(state.highestPriorityState, .idle)
    }

    @MainActor
    func testActiveSessionCount() {
        let state = AppState()
        state.sessions = [
            makeSession(id: "s1", state: .active),
            makeSession(id: "s2", state: .idle),
            makeSession(id: "s3", state: .stopped),
        ]
        XCTAssertEqual(state.activeSessionCount, 2)
    }

    @MainActor
    func testPendingPermissionCount() {
        let state = AppState()
        var session = makeSession(id: "s1", state: .waitingPermission)
        session.pendingPermissions = [
            PermissionRequest(sessionId: "s1", toolName: "Bash"),
            PermissionRequest(sessionId: "s1", toolName: "Write"),
        ]
        state.sessions = [session]
        XCTAssertEqual(state.pendingPermissionCount, 2)
    }

    @MainActor
    func testPendingPermissionCountExcludesResolved() {
        let state = AppState()
        var session = makeSession(id: "s1", state: .waitingPermission)
        session.pendingPermissions = [
            PermissionRequest(sessionId: "s1", toolName: "Bash"),
            PermissionRequest(sessionId: "s1", toolName: "Write", isResolved: true),
        ]
        state.sessions = [session]
        XCTAssertEqual(state.pendingPermissionCount, 1)
    }

    @MainActor
    func testStatusIconReflectsState() {
        let state = AppState()
        state.sessions = [makeSession(id: "s1", state: .waitingPermission)]
        XCTAssertEqual(state.statusIcon, "exclamationmark.bubble.fill")

        state.sessions = [makeSession(id: "s1", state: .active)]
        XCTAssertEqual(state.statusIcon, "bolt.fill")

        state.sessions = [makeSession(id: "s1", state: .error)]
        XCTAssertEqual(state.statusIcon, "exclamationmark.triangle.fill")
    }

    @MainActor
    func testNotificationAddAndRemove() {
        let state = AppState()
        let notif = NotificationItem(
            sessionId: "s1",
            projectName: "Test",
            title: "Done",
            message: "Claude finished",
            style: .success
        )
        state.addNotification(notif)
        XCTAssertEqual(state.notifications.count, 1)

        state.removeNotification(id: notif.id)
        XCTAssertEqual(state.notifications.count, 0)
    }

    @MainActor
    func testNotificationCapsAt50() {
        let state = AppState()
        for i in 0..<60 {
            state.addNotification(NotificationItem(
                sessionId: "s\(i)",
                projectName: "Test",
                title: "Done \(i)",
                message: "Message",
                style: .success
            ))
        }
        XCTAssertEqual(state.notifications.count, 50)
    }

    @MainActor
    func testUpdateFromSessionAddsNew() {
        let state = AppState()
        let session = makeSession(id: "s1", state: .active)
        state.updateFromSession(session)
        XCTAssertEqual(state.sessions.count, 1)
    }

    @MainActor
    func testUpdateFromSessionUpdatesExisting() {
        let state = AppState()
        let session1 = makeSession(id: "s1", state: .active)
        state.updateFromSession(session1)

        var session2 = makeSession(id: "s1", state: .idle)
        session2.projectName = "Updated"
        state.updateFromSession(session2)

        XCTAssertEqual(state.sessions.count, 1)
        XCTAssertEqual(state.sessions.first?.state, .idle)
    }

    // MARK: - Helpers

    private func makeSession(id: String, state: SessionState) -> AgentSession {
        AgentSession(
            id: id,
            state: state,
            projectName: "TestProject",
            accentColor: .blue,
            startedAt: Date(),
            lastEventAt: Date(),
            pendingPermissions: [],
            recentEvents: RingBuffer<HookEvent>(capacity: 50),
            stats: SessionStats()
        )
    }
}
