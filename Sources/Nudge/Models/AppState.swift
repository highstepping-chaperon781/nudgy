import Foundation
import SwiftUI

/// Observable state that drives all UI.
@MainActor
@Observable
final class AppState {
    var sessions: [AgentSession] = []
    var notifications: [NotificationItem] = []
    var isServerRunning: Bool = false
    var port: UInt16 = 9847

    // MARK: - Computed Properties

    var activeSessionCount: Int {
        sessions.filter { $0.state != .stopped }.count
    }

    var highestPriorityState: SessionState {
        sessions
            .filter { $0.state != .stopped }
            .max(by: { $0.state.priority < $1.state.priority })?
            .state ?? .idle
    }

    var pendingPermissionCount: Int {
        sessions.reduce(0) { $0 + $1.pendingPermissions.filter { !$0.isResolved }.count }
    }

    /// SF Symbol name for the menubar icon.
    var statusIcon: String {
        switch highestPriorityState {
        case .waitingPermission: return "exclamationmark.bubble.fill"
        case .error:             return "exclamationmark.triangle.fill"
        case .waitingInput:      return "questionmark.bubble.fill"
        case .active:            return "bolt.fill"
        case .idle:              return "checkmark.circle.fill"
        case .stopped:           return "circle"
        }
    }

    /// Color for the menubar icon.
    var iconColor: Color {
        switch highestPriorityState {
        case .waitingPermission: return Color(red: 1.0, green: 0.6, blue: 0.15)
        case .error:             return Color(red: 1.0, green: 0.35, blue: 0.25)
        case .waitingInput:      return Color(red: 1.0, green: 0.78, blue: 0.3)
        case .active:            return Color(red: 1.0, green: 0.6, blue: 0.15)
        case .idle:              return Color(red: 0.55, green: 0.52, blue: 0.5)
        case .stopped:           return Color(red: 0.55, green: 0.52, blue: 0.5)
        }
    }

    // MARK: - Mutations

    func addNotification(_ item: NotificationItem) {
        notifications.insert(item, at: 0)
        // Keep only last 50 notifications
        if notifications.count > 50 {
            notifications = Array(notifications.prefix(50))
        }
    }

    func removeNotification(id: UUID) {
        notifications.removeAll { $0.id == id }
    }

    func updateFromSession(_ session: AgentSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func removeSession(id: String) {
        sessions.removeAll { $0.id == id }
    }
}
