import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("com.nudgy.openSettings")
}

@MainActor
struct MenuBarView: View {
    let appState: AppState
    let onFocusSession: ((AgentSession) -> Void)?
    var quotaManager: UsageQuotaManager?

    init(appState: AppState, onFocusSession: ((AgentSession) -> Void)? = nil, quotaManager: UsageQuotaManager? = nil) {
        self.appState = appState
        self.onFocusSession = onFocusSession
        self.quotaManager = quotaManager
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
            // Session dots
            if !activeSessions.isEmpty {
                SessionDotsView(
                    sessions: activeSessions,
                    onTap: { session in onFocusSession?(session) }
                )
                thinDivider
            }

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

            // Quota
            if let quota = quotaManager?.quota {
                QuotaBarView(quota: quota)
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
                    .frame(width: 6, height: 6)
                Text("\(needsAttention.count) need\(needsAttention.count == 1 ? "s" : "") you")
                    .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.45))
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
            .font(.system(size: 11))
            .foregroundStyle(.primary.opacity(0.5))

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.primary.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.08))
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
                    .frame(width: 7, height: 7)

                Text(session.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(waitTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.5))
            }

            // Detail line: what's waiting
            HStack(spacing: 0) {
                if session.state == .waitingPermission {
                    if let lastPerm = session.pendingPermissions.last {
                        Text(lastPerm.toolName.isEmpty ? "Needs permission" : lastPerm.toolName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentColor)

                        if let cmd = lastPerm.command {
                            Text(" · ")
                                .foregroundStyle(.primary.opacity(0.3))
                                .font(.system(size: 11))
                            Text(cmd.prefix(40) + (cmd.count > 40 ? "..." : ""))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.65))
                                .lineLimit(1)
                        }
                    } else {
                        Text("Waiting for permission")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentColor)
                    }
                } else {
                    Text("Has a question")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accentColor)
                }

                Spacer()

                Button(action: onFocus) {
                    Text("Go")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(accentColor.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(hovered ? 0.06 : 0))
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
                .frame(width: 6, height: 6)

            Text(session.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(stateText)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.55))

            if let usage = session.tokenUsage {
                Text(usage.formattedTokens)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.45))
            }

            Text(ago)
                .font(.system(size: 10))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(hovered ? 0.05 : 0))
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
                .frame(width: 4, height: 4)

            Text(notification.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.75))
                .lineLimit(1)

            Text(notification.projectName)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.4))
                .lineLimit(1)

            Spacer()

            Text(ago)
                .font(.system(size: 10))
                .foregroundStyle(.primary.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }

    private var ago: String {
        let s = Date().timeIntervalSince(notification.timestamp)
        if s < 5 { return "now" }
        if s < 60 { return "\(Int(s))s" }
        if s < 3600 { return "\(Int(s / 60))m" }
        return "\(Int(s / 3600))h"
    }
}

// MARK: - Session Dots

struct SessionDotsView: View {
    let sessions: [AgentSession]
    let onTap: ((AgentSession) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(sessions) { session in
                SessionDotBar(session: session)
                    .onTapGesture { onTap?(session) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

private struct SessionDotBar: View {
    let session: AgentSession
    @State private var isBlinking = false

    private var shouldBlink: Bool {
        session.state == .active || session.isActionRequired
    }

    private var dotColor: Color {
        switch session.state {
        case .active:            return Color(red: 1.0, green: 0.6, blue: 0.15)
        case .idle:              return Color(red: 0.3, green: 0.8, blue: 0.65)
        case .waitingPermission: return Color(red: 1.0, green: 0.6, blue: 0.15)
        case .waitingInput:      return Color(red: 1.0, green: 0.78, blue: 0.3)
        case .error:             return Color(red: 1.0, green: 0.35, blue: 0.25)
        case .stopped:           return Color(red: 0.35, green: 0.35, blue: 0.35)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(dotColor)
            .frame(width: 16, height: 4)
            .opacity(shouldBlink ? (isBlinking ? 1.0 : 0.4) : 0.7)
            .onAppear {
                guard shouldBlink else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            }
            .help(session.displayName)
    }
}

// MARK: - Quota Bar

private struct QuotaBarView: View {
    let quota: UsageQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(quota.tier.capitalized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
                Spacer()
                Text(String(format: "%.0f%% remaining", quota.remaining))
                    .font(.system(size: 10))
                    .foregroundStyle(quota.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.primary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(quota.color)
                        .frame(width: geo.size.width * (quota.remaining / 100))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}
