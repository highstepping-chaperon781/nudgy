import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("com.nudge.openSettings")
}

struct MenuBarView: View {
    let appState: AppState
    let onFocusSession: ((AgentSession) -> Void)?

    init(appState: AppState, onFocusSession: ((AgentSession) -> Void)? = nil) {
        self.appState = appState
        self.onFocusSession = onFocusSession
    }

    private var activeSessions: [AgentSession] {
        appState.sessions.filter { $0.state != .stopped }
    }

    private var needsAttention: [AgentSession] {
        activeSessions.filter { $0.isActionRequired }
    }

    private var backgroundSessions: [AgentSession] {
        activeSessions.filter { !$0.isActionRequired }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Attention section
            if !needsAttention.isEmpty {
                attentionSection
                thinDivider
            }

            // Background sessions
            if !backgroundSessions.isEmpty {
                backgroundSection
                thinDivider
            }

            // Empty state
            if activeSessions.isEmpty {
                emptyState
                thinDivider
            }

            // Recent timeline
            if !appState.notifications.isEmpty {
                recentSection
                thinDivider
            }

            // Footer
            footer
        }
        .frame(width: 280)
    }

    // MARK: - Attention

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Attention header
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.6, blue: 0.15))
                    .frame(width: 5, height: 5)
                Text("\(needsAttention.count) need\(needsAttention.count == 1 ? "s" : "") you")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.15))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ForEach(needsAttention) { session in
                AttentionRow(session: session) {
                    onFocusSession?(session)
                }
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Background

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(backgroundSessions) { session in
                CompactRow(session: session)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 3) {
                Text("No active sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(appState.notifications.prefix(5)) { n in
                RecentRow(notification: n)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Settings...") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5))
            .foregroundStyle(.tertiary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5))
            .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.horizontal, 10)
    }
}

// MARK: - Attention Row (expanded, with detail + Go button)

private struct AttentionRow: View {
    let session: AgentSession
    let onFocus: () -> Void
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)

                Text(session.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text(waitTime)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Detail line: what's waiting
            HStack(spacing: 0) {
                if session.state == .waitingPermission {
                    if let lastPerm = session.pendingPermissions.last {
                        Text(lastPerm.toolName.isEmpty ? "Needs permission" : lastPerm.toolName)
                            .font(.system(size: 10.5))
                            .foregroundStyle(accentColor.opacity(0.8))

                        if let cmd = lastPerm.command {
                            Text(" · ")
                                .foregroundStyle(.quaternary)
                                .font(.system(size: 10))
                            Text(cmd.prefix(40) + (cmd.count > 40 ? "..." : ""))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Waiting for permission")
                            .font(.system(size: 10.5))
                            .foregroundStyle(accentColor.opacity(0.8))
                    }
                } else {
                    Text("Has a question")
                        .font(.system(size: 10.5))
                        .foregroundStyle(accentColor.opacity(0.8))
                }

                Spacer()

                Button(action: onFocus) {
                    Text("Go")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule().fill(accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(hovered ? 0.04 : 0))
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }

    private var accentColor: Color {
        session.state == .waitingPermission
            ? Color(red: 1.0, green: 0.6, blue: 0.15)
            : Color(red: 1.0, green: 0.78, blue: 0.3)
    }

    private var waitTime: String {
        let s = Date().timeIntervalSince(session.lastEventAt)
        if s < 5 { return "now" }
        if s < 60 { return "\(Int(s))s" }
        if s < 3600 { return "\(Int(s / 60))m" }
        return "\(Int(s / 3600))h"
    }
}

// MARK: - Compact Row (one-line for working/done sessions)

private struct CompactRow: View {
    let session: AgentSession
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)

            Text(session.displayName)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)

            Spacer()

            Text(stateText)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Text(ago)
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(hovered ? 0.03 : 0))
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }

    private var dotColor: Color {
        switch session.state {
        case .active: return Color(red: 1.0, green: 0.6, blue: 0.15)
        case .idle:   return Color(red: 0.3, green: 0.8, blue: 0.65)
        case .error:  return Color(red: 1.0, green: 0.35, blue: 0.25)
        default:      return Color(red: 0.55, green: 0.52, blue: 0.5)
        }
    }

    private var stateText: String {
        switch session.state {
        case .active: return "working"
        case .idle:   return "done"
        case .error:  return "error"
        default:      return ""
        }
    }

    private var ago: String {
        let s = Date().timeIntervalSince(session.lastEventAt)
        if s < 5 { return "" }
        if s < 60 { return "\(Int(s))s" }
        if s < 3600 { return "\(Int(s / 60))m" }
        return "\(Int(s / 3600))h"
    }
}

// MARK: - Recent Row

private struct RecentRow: View {
    let notification: NotificationItem

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(notification.style.color)
                .frame(width: 3.5, height: 3.5)

            Text(notification.title)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(notification.projectName)
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .lineLimit(1)

            Spacer()

            Text(ago)
                .font(.system(size: 9.5))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2.5)
    }

    private var ago: String {
        let s = Date().timeIntervalSince(notification.timestamp)
        if s < 5 { return "now" }
        if s < 60 { return "\(Int(s))s" }
        if s < 3600 { return "\(Int(s / 60))m" }
        return "\(Int(s / 3600))h"
    }
}
