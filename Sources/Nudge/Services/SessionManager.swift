import Foundation
import SwiftUI

/// Thread-safe session state manager.
actor SessionManager {
    private var sessions: [String: AgentSession] = [:]
    private let appState: AppState
    private var cleanupTask: Task<Void, Never>?
    private var colorIndex: Int = 0

    private static let accentColors: [Color] = [
        .blue, .purple, .orange, .pink, .cyan, .mint, .indigo, .teal
    ]

    private static let staleThreshold: TimeInterval = 300 // 5 minutes

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Event Processing

    func handleEvent(_ event: HookEvent) async {
        let sessionId = event.sessionId ?? "unknown"

        var session = sessions[sessionId] ?? AgentSession(
            id: sessionId,
            state: .active,
            projectName: Self.projectName(from: event.cwd),
            workingDirectory: event.cwd,
            accentColor: nextAccentColor(),
            startedAt: Date(),
            lastEventAt: Date(),
            pendingPermissions: [],
            recentEvents: RingBuffer<HookEvent>(capacity: 50),
            stats: SessionStats()
        )

        switch event.hookEventName {
        case "SessionStart":
            session.state = .active

        case "Stop":
            session.state = .idle

        case "Notification":
            let matcher = event.matcher ?? ""
            if matcher.contains("permission") {
                session.state = .waitingPermission
                session.pendingPermissions.append(PermissionRequest(from: event))
                session.stats.permissionCount += 1
            } else if matcher.contains("idle") || matcher.contains("input") || matcher.contains("question") {
                session.state = .waitingInput
            }
            // For any other notification, keep current state but record the event

        case "StopFailure":
            if event.matcher == "max_output_tokens" {
                session.state = .idle
            } else {
                session.state = .error
                session.stats.errorCount += 1
            }

        case "SessionEnd":
            session.state = .stopped

        case "PreToolUse":
            session.state = .active

        case "PermissionRequest":
            // Permission dialog is being shown to the user RIGHT NOW
            session.state = .waitingPermission
            session.pendingPermissions.append(PermissionRequest(from: event))
            session.stats.permissionCount += 1

        default:
            break
        }

        session.lastEventAt = Date()
        session.recentEvents.append(event)
        session.stats.eventCount += 1
        sessions[sessionId] = session

        let updatedSession = session
        await MainActor.run {
            appState.updateFromSession(updatedSession)
        }
    }

    // MARK: - Session Queries

    func session(for id: String) -> AgentSession? {
        sessions[id]
    }

    func activeSessions() -> [AgentSession] {
        sessions.values.filter { $0.state != .stopped }
    }

    func allSessions() -> [AgentSession] {
        Array(sessions.values)
    }

    func removeSession(id: String) async {
        sessions.removeValue(forKey: id)
        await MainActor.run {
            appState.removeSession(id: id)
        }
    }

    // MARK: - Stale Session Cleanup

    func startCleanupTimer() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60s
                await self?.cleanupStaleSessions()
            }
        }
    }

    func stopCleanupTimer() {
        cleanupTask?.cancel()
        cleanupTask = nil
    }

    func cleanupStaleSessions() async {
        let now = Date()
        let staleIds = sessions.filter { _, session in
            session.state != .stopped &&
            now.timeIntervalSince(session.lastEventAt) > Self.staleThreshold
        }.map(\.key)

        for id in staleIds {
            sessions[id]?.state = .stopped
            if let session = sessions[id] {
                await MainActor.run {
                    appState.updateFromSession(session)
                }
            }
        }
    }

    // MARK: - Helpers

    private func nextAccentColor() -> Color {
        let color = Self.accentColors[colorIndex % Self.accentColors.count]
        colorIndex += 1
        return color
    }

    static func projectName(from cwd: String?) -> String {
        guard let cwd = cwd else { return "Unknown" }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}
