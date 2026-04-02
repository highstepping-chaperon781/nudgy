# End-to-End Test Specifications

## Purpose
E2E tests simulate real AI coding agent usage patterns from the outside —
sending HTTP requests that mimic what AI coding agent hooks would actually send,
and verifying the complete user-visible outcome.

## Test Scenarios

### Scenario 1: Developer Asks Claude to Refactor, Switches to Slack

**Simulates**: The most common use case — Claude works while the developer
is in another app.

```
Timeline:
  0s   POST SessionStart (cwd: /Users/dev/myproject)
  0.5s POST Stop (Claude finished)

Expected:
  - Session "myproject" created
  - After Stop: floating popup appears with "Claude Finished"
  - Popup auto-dismisses after 6 seconds
  - Menubar icon: green checkmark, then back to blue circle
  - Sound: Glass.aiff plays
```

### Scenario 2: Claude Needs Permission During Developer's Meeting

**Simulates**: Permission blocked while developer is away.

```
Timeline:
  0s    POST SessionStart
  2s    POST Notification (matcher: permission_prompt)
  ...   (developer doesn't respond)
  120s  Escalation: sound replays, menubar pulses

Expected:
  - Session created, state → .waitingPermission
  - Floating popup: amber, "Permission Required", NO auto-dismiss
  - Popup persists for entire duration
  - At 120s: escalation triggers (sound, visual emphasis)
  - Menubar icon: amber warning badge the entire time
```

### Scenario 3: Multiple Projects Running

**Simulates**: Developer running Claude on 3 projects simultaneously.

```
Timeline:
  0s    POST SessionStart (session: s1, cwd: /backend)
  1s    POST SessionStart (session: s2, cwd: /frontend)
  2s    POST SessionStart (session: s3, cwd: /infra)
  5s    POST Stop (session: s1)
  6s    POST Notification(permission_prompt) (session: s2)
  8s    POST StopFailure (session: s3)

Expected:
  - 3 sessions tracked, each with different accent color
  - s1 Stop: success popup tagged "backend"
  - s2 Permission: warning popup tagged "frontend" (persistent)
  - s3 Error: error popup tagged "infra"
  - Menubar dropdown: 3 sessions listed with correct states
  - Menubar icon: reflects permission (highest priority)
  - Popups stack without overlap (up to 3 visible)
```

### Scenario 4: Rapid-Fire Tool Calls

**Simulates**: Claude reading many files quickly (generates many events).

```
Timeline:
  0s     POST SessionStart
  0.5s   POST Stop
  1.0s   POST Stop
  1.5s   POST Stop
  2.0s   POST Stop
  2.5s   POST Stop
  (5 Stop events in 2.5 seconds)

Expected:
  - Smart suppressor batches these
  - At most 1-2 notifications shown (not 5)
  - Or: suppressed entirely if each "session" was fast (< 5s)
```

### Scenario 5: Session Crash (No SessionEnd)

**Simulates**: AI coding agent process dies without clean shutdown.

```
Timeline:
  0s    POST SessionStart
  ...   (no more events for 6 minutes)

Expected:
  - Session created, state .active
  - After 5 minutes: cleanup timer marks session as stale
  - Session state → .stopped
  - Session removed from active list in menubar dropdown
```

### Scenario 6: Hook Install on Clean System

**Simulates**: First-time user installs Nudge.

```
Preconditions:
  - ~/.claude/settings.json does not exist

Steps:
  1. Run HookInstaller.install()

Expected:
  - ~/.claude/ directory created
  - ~/.claude/settings.json created with our hooks
  - isInstalled() returns true
  - verify() returns true
  - JSON is valid and pretty-printed
```

### Scenario 7: Hook Install on Existing Config

**Simulates**: User already has AI coding agent configured with custom hooks.

```
Preconditions:
  - ~/.claude/settings.json exists with:
    {
      "hooks": {
        "PreToolUse": [{"hooks": [{"type": "command", "command": "lint.sh"}]}],
        "Stop": [{"hooks": [{"type": "command", "command": "notify.sh"}]}]
      },
      "permissions": {"allow": ["Read", "Glob"]},
      "model": "sonnet"
    }

Steps:
  1. Run HookInstaller.install()

Expected:
  - Backup file created: settings.json.backup.YYYY-MM-DD-HHMMSS
  - User's PreToolUse hook: PRESERVED
  - User's Stop hook: PRESERVED (our hook APPENDED alongside)
  - User's permissions: PRESERVED
  - User's model setting: PRESERVED
  - Our hooks added for: Stop, Notification, StopFailure, SessionStart, SessionEnd
  - JSON is valid and readable
```

### Scenario 8: Full Install → Use → Uninstall

**Simulates**: Complete app lifecycle.

```
Steps:
  1. Install hooks
  2. Verify hooks work (send test event, see popup)
  3. Uninstall hooks
  4. Verify settings.json has no Nudge remnants
  5. Verify user's original hooks are still intact
```

## Validation Methods

For each scenario, verify:

1. **State correctness**: `sessionManager.session(for:)?.state`
2. **Notification created**: `appState.notifications.count`
3. **Notification style**: `.success`, `.warning`, `.error`, `.question`
4. **Popup visibility**: Check if NSPanel is ordered front
5. **Menubar icon**: Read `statusItem.button?.image` or `.title`
6. **Sound played**: (Cannot verify in tests — use flag/mock)
7. **File integrity**: Read and parse settings.json after operations
8. **Performance**: Measure wall-clock time for event processing

## Test Infrastructure

```swift
/// Helper to run a scenario with timed events
func runScenario(_ events: [(delay: TimeInterval, json: [String: Any])]) async {
    for event in events {
        try? await Task.sleep(for: .seconds(event.delay))
        try? await sendEvent(port: server.actualPort, json: event.json)
    }
}
```
