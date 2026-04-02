import Foundation
import SwiftUI

/// Represents a tracked AI coding agent session.
struct AgentSession: Identifiable, Sendable {
    let id: String // session_id from hook
    var state: SessionState
    var projectName: String
    var workingDirectory: String?
    var terminalApp: String?
    var terminalPID: pid_t?
    var accentColor: Color
    var startedAt: Date
    var lastEventAt: Date
    var pendingPermissions: [PermissionRequest]
    var recentEvents: RingBuffer<HookEvent>
    var stats: SessionStats
    var tokenUsage: TokenUsage?

    /// Whether this session requires user action.
    var isActionRequired: Bool {
        state == .waitingPermission || state == .waitingInput
    }

    /// Display name: project name or truncated session ID.
    var displayName: String {
        if !projectName.isEmpty {
            return projectName
        }
        if id.count > 12 {
            return String(id.prefix(12)) + "..."
        }
        return id
    }

    /// Duration since session started.
    var duration: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
}

/// Possible states for an agent session.
enum SessionState: String, CaseIterable, Sendable {
    case active
    case idle
    case waitingPermission
    case waitingInput
    case error
    case stopped

    var priority: Int {
        switch self {
        case .waitingPermission: return 100
        case .error:             return 90
        case .waitingInput:      return 80
        case .active:            return 50
        case .idle:              return 10
        case .stopped:           return 0
        }
    }
}

/// A pending permission request from the agent.
struct PermissionRequest: Identifiable, Sendable {
    let id: UUID
    let sessionId: String
    let toolName: String
    let command: String?
    let filePath: String?
    let timestamp: Date
    var isResolved: Bool

    init(
        id: UUID = UUID(),
        sessionId: String,
        toolName: String = "",
        command: String? = nil,
        filePath: String? = nil,
        timestamp: Date = Date(),
        isResolved: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.toolName = toolName
        self.command = command
        self.filePath = filePath
        self.timestamp = timestamp
        self.isResolved = isResolved
    }

    init(from event: HookEvent) {
        self.id = UUID()
        self.sessionId = event.sessionId ?? "unknown"
        self.toolName = event.toolName ?? ""
        self.command = event.toolInput?["command"]?.value as? String
        self.filePath = event.toolInput?["file_path"]?.value as? String
        self.timestamp = event.timestamp
        self.isResolved = false
    }
}

/// Aggregate statistics for a session.
struct SessionStats: Sendable {
    var eventCount: Int = 0
    var permissionCount: Int = 0
    var errorCount: Int = 0
    var totalDuration: TimeInterval = 0
}
