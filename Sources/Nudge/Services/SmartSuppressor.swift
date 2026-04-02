import Cocoa

/// Decision returned by the suppression engine.
enum SuppressionDecision: Equatable {
    case show
    case suppress(reason: String)
    case batch(groupId: String)
    case escalate
}

/// Decides whether a notification should be shown, suppressed, or batched.
final class SmartSuppressor {
    var isEnabled: Bool = true
    var suppressWhenTerminalFocused: Bool = false // Off by default — too aggressive
    var fastCompletionThreshold: TimeInterval = 5.0
    var batchWindow: TimeInterval = 10.0
    var recentInteractionWindow: TimeInterval = 10.0
    var escalationThreshold: TimeInterval = 120.0

    private var lastInteractionTime: Date?
    private var recentEvents: [(sessionId: String, time: Date)] = []
    private let windowFocuser: WindowFocuser

    init(windowFocuser: WindowFocuser) {
        self.windowFocuser = windowFocuser
    }

    /// Evaluate whether a notification should be shown.
    func evaluate(event: HookEvent, session: AgentSession) -> SuppressionDecision {
        guard isEnabled else { return .show }

        // RULE 0: Permission requests, errors, and questions are NEVER suppressed
        if session.state == .waitingPermission || session.state == .error || session.state == .waitingInput {
            return checkEscalation(session: session)
        }

        // RULE 1: Terminal is focused → suppress (only if enabled)
        if suppressWhenTerminalFocused && windowFocuser.isTerminalFocused() {
            return .suppress(reason: "Terminal is focused")
        }

        // RULE 2: Rapid-fire events → batch (check before fast completion)
        let recentCount = recentEventsCount(for: session.id, within: batchWindow)
        if recentCount >= 3 && session.state == .idle {
            return .batch(groupId: session.id)
        }

        return .show
    }

    /// Record that the user interacted with a notification.
    func recordInteraction() {
        lastInteractionTime = Date()
    }

    /// Record an event for batching logic.
    func recordEvent(_ event: HookEvent) {
        let now = Date()
        recentEvents.append((sessionId: event.sessionId ?? "unknown", time: now))
        recentEvents.removeAll { now.timeIntervalSince($0.time) > batchWindow * 2 }
    }

    // MARK: - Private

    private func recentEventsCount(for sessionId: String, within window: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-window)
        return recentEvents.count { $0.sessionId == sessionId && $0.time > cutoff }
    }

    private func checkEscalation(session: AgentSession) -> SuppressionDecision {
        if let oldest = session.pendingPermissions.first(where: { !$0.isResolved }),
           Date().timeIntervalSince(oldest.timestamp) > escalationThreshold {
            return .escalate
        }
        return .show
    }
}
