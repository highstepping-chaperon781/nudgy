# Agent 09: Smart Notification Suppression

## Objective
Implement the intelligence layer that decides whether a notification should
be shown, suppressed, or batched. This prevents notification fatigue —
the #1 risk to user retention.

## Scope
- Rule engine with ordered evaluation
- Focus detection (is terminal active?)
- Timing-based suppression (fast completions)
- Rapid-fire batching
- Recent interaction awareness
- Permission requests are NEVER suppressed
- Configurable thresholds
- Escalation logic for stale permission requests

## Dependencies
- Agent 03: AppState, AgentSession, SessionState
- Agent 04: PopupWindowController (to check if popups are already visible)
- Agent 07: WindowFocuser.isTerminalFocused()

## Files to Create

### Sources/Nudge/Services/SmartSuppressor.swift

```swift
import Cocoa

enum SuppressionDecision {
    case show                          // Show the notification
    case suppress(reason: String)      // Don't show, log reason
    case batch(groupId: String)        // Defer, batch with similar events
    case escalate                      // Show with higher urgency
}

final class SmartSuppressor {
    var isEnabled: Bool = true
    var fastCompletionThreshold: TimeInterval = 5.0  // seconds
    var batchWindow: TimeInterval = 10.0             // seconds
    var recentInteractionWindow: TimeInterval = 10.0 // seconds

    private var lastInteractionTime: Date?
    private var recentEvents: [(event: HookEvent, time: Date)] = []
    private let windowFocuser: WindowFocuser

    init(windowFocuser: WindowFocuser) {
        self.windowFocuser = windowFocuser
    }

    /// Evaluate whether a notification should be shown
    func evaluate(
        event: HookEvent,
        session: AgentSession
    ) -> SuppressionDecision {
        guard isEnabled else { return .show }

        // RULE 0: Permission requests and errors are NEVER suppressed
        if session.state == .waitingPermission || session.state == .error {
            return checkEscalation(session: session)
        }

        // RULE 1: Terminal is focused → suppress
        if isSessionTerminalFocused(session) {
            return .suppress(reason: "Terminal is focused")
        }

        // RULE 2: Fast completion → suppress
        if event.hookEventName == "Stop" {
            let sessionDuration = session.lastEventAt
                .timeIntervalSince(session.startedAt)
            if sessionDuration < fastCompletionThreshold {
                return .suppress(reason: "Fast completion (\(sessionDuration)s)")
            }
        }

        // RULE 3: Recent interaction → suppress informational
        if let lastInteraction = lastInteractionTime,
           Date().timeIntervalSince(lastInteraction) < recentInteractionWindow,
           session.state == .idle {
            return .suppress(reason: "Recent interaction")
        }

        // RULE 4: Rapid-fire events → batch
        let recentCount = recentEventsCount(
            for: session.id,
            within: batchWindow
        )
        if recentCount >= 3 && session.state == .idle {
            return .batch(groupId: session.id)
        }

        return .show
    }

    /// Record that the user interacted (dismissed popup, approved, etc.)
    func recordInteraction() {
        lastInteractionTime = Date()
    }

    /// Record an event for batching logic
    func recordEvent(_ event: HookEvent) {
        let now = Date()
        recentEvents.append((event: event, time: now))
        // Prune events older than batchWindow
        recentEvents.removeAll { now.timeIntervalSince($0.time) > batchWindow * 2 }
    }

    // MARK: - Private

    private func isSessionTerminalFocused(_ session: AgentSession) -> Bool {
        // Check if the specific session's terminal is the frontmost window
        // If we can't determine the specific window, check if ANY terminal
        // is focused (conservative approach)
        return windowFocuser.isTerminalFocused()
    }

    private func recentEventsCount(for sessionId: String, within window: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-window)
        return recentEvents.count { event in
            event.event.sessionId == sessionId && event.time > cutoff
        }
    }

    private func checkEscalation(session: AgentSession) -> SuppressionDecision {
        // If permission has been pending for > 2 minutes, escalate
        if let oldest = session.pendingPermissions.first(where: { !$0.isResolved }),
           Date().timeIntervalSince(oldest.timestamp) > 120 {
            return .escalate
        }
        return .show
    }
}
```

### Escalation Behavior

When a permission request has been pending for too long:

| Duration | Behavior |
|----------|----------|
| 0-30s | Standard notification |
| 30s-2min | Notification stays persistent (no auto-dismiss) |
| 2-5min | `.escalate` → play sound again, pulse menubar icon |
| 5min+ | `.escalate` → show floating reminder on any window activation |

### Batching Behavior

When 3+ events from the same session arrive within 10s:
- Suppress individual notifications
- After the batch window expires, show ONE summary notification:
  "easychef-backend: 5 events completed"
- Implementation: use a delayed task that fires after batchWindow + 1s,
  checks if there are batched events, and creates a summary notification

## Tests to Write

### Tests/NudgeTests/SmartSuppressorTests.swift

```
testPermissionRequestIsNeverSuppressed
    → Session in .waitingPermission → decision is .show

testErrorIsNeverSuppressed
    → Session in .error → decision is .show

testSuppressWhenTerminalFocused
    → Mock isTerminalFocused = true → decision is .suppress

testSuppressFastCompletion
    → Session duration = 2s, threshold = 5s → decision is .suppress

testShowSlowCompletion
    → Session duration = 10s, threshold = 5s → decision is .show

testSuppressAfterRecentInteraction
    → recordInteraction() 5s ago, informational event → .suppress

testShowAfterInteractionWindowExpires
    → recordInteraction() 15s ago, window = 10s → .show

testBatchRapidFireEvents
    → 4 events from same session in 10s → .batch

testShowWhenEventsAreSpreadOut
    → 2 events in 10s → .show (below threshold)

testEscalateStalePermission
    → Permission pending for 3 minutes → .escalate

testDisabledSuppressionAlwaysShows
    → isEnabled = false → always .show

testConfigurableThresholds
    → Set fastCompletionThreshold to 2s → 3s completion shows

testDifferentSessionsTrackedSeparately
    → Rapid events from session A, single event from session B →
      session A batched, session B shows
```

## Self-Verification

1. `swift build` compiles
2. All 13 tests pass
3. Permission requests ALWAYS pass through (verify with 100 random scenarios)
4. Suppression reasons are logged for debugging
5. No false suppression of actionable notifications
