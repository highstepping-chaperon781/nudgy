# Agent 07: Window Focus Detection

## Objective
Implement the ability to find and activate the terminal/editor window
running a specific AI coding agent session, so clicking "Focus" on a
notification brings the user to the right window.

## Scope
- Detect running terminal/editor apps (Terminal, iTerm2, VS Code, Cursor, Claude Desktop)
- Match a session to a specific app window
- Activate (bring to front) the matched window
- Detect whether the terminal is currently focused (for suppression logic)
- Handle edge cases: multiple windows, tabs, tmux

## Dependencies
- Agent 01: Project structure
- Agent 03: AgentSession model (terminalPID, terminalApp fields)

## Files to Create

### Sources/Nudge/Services/WindowFocuser.swift

```swift
import Cocoa
import ApplicationServices

final class WindowFocuser {

    /// Known terminal/editor bundle IDs
    static let knownApps: [String: String] = [
        "com.apple.Terminal":                    "Terminal",
        "com.googlecode.iterm2":                 "iTerm2",
        "net.kovidgoyal.kitty":                  "Kitty",
        "com.mitchellh.ghostty":                 "Ghostty",
        "dev.warp.Warp-Stable":                  "Warp",
        "com.microsoft.VSCode":                  "VS Code",
        "com.todesktop.230313mzl4w4u92":         "Cursor",
        "com.anthropic.claudedesktop":           "Claude Desktop",
    ]

    /// Focus the window running the given session
    func focusSession(_ session: AgentSession) -> Bool {
        // Strategy chain:
        // 1. If terminalPID is known → activate by PID
        // 2. If terminalApp is known → find window by app + title
        // 3. Fallback → activate any known terminal app
        ...
    }

    /// Check if any known terminal is the frontmost app
    func isTerminalFocused() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        return Self.knownApps.keys.contains(frontApp.bundleIdentifier ?? "")
    }

    /// Detect which terminal app a session is running in
    func detectTerminalApp(pid: pid_t?) -> (bundleId: String, name: String)? {
        // Walk up the process tree from the given PID to find a known app
        ...
    }

    // MARK: - Private

    /// Activate an app by PID
    private func activateByPID(_ pid: pid_t) -> Bool {
        let apps = NSRunningApplication.runningApplications(
            withBundleIdentifier: ""
        )
        // Find by PID, call activate()
        ...
    }

    /// Find window by title match using CGWindowList
    private func findWindow(
        appPID: pid_t,
        titleContaining: String
    ) -> CGWindowID? {
        // Requires Screen Recording permission
        ...
    }

    /// Bring a specific window to front using Accessibility API
    private func raiseWindow(
        appPID: pid_t,
        windowID: CGWindowID
    ) -> Bool {
        // Requires Accessibility permission
        ...
    }
}
```

### Fallback Chain

```
1. Try: NSRunningApplication(pid).activate()
   ✓ → Done (brings app to front, but may not focus the right tab)

2. Try: CGWindowListCopyWindowInfo to find window by title
   → Then AXUIElement to raise that specific window
   ✓ → Done (focuses exact window/tab)

3. Try: AppleScript for app-specific targeting
   → e.g., iTerm2: `tell application "iTerm2" to select first window`
   ✓ → Done

4. Fallback: Find any running known terminal app and activate it
   → Better than nothing
```

### Permissions Required

- **Accessibility** (optional but recommended):
  Required for AXUIElement window targeting.
  Check with: `AXIsProcessTrusted()`

- **Screen Recording** (optional):
  Required for CGWindowList window name access.
  Without it, can still get window bounds but not titles.

The app should work WITHOUT these permissions (using fallback chain steps 1
and 4), but with reduced precision.

## Tests to Write

### Tests/NudgeTests/WindowFocuserTests.swift

```
testKnownAppsContainsExpectedBundleIds
    → Verify all 8 known apps are in the dictionary

testIsTerminalFocusedWhenTerminalIsFront
    → Mock frontmostApplication as Terminal → returns true

testIsTerminalFocusedWhenSafariIsFront
    → Mock frontmostApplication as Safari → returns false

testDetectTerminalAppFromPID
    → Given a PID of a known app → returns correct bundle ID

testFocusSessionActivatesApp
    → Given a session with terminalPID → app.activate() is called

testFocusSessionFallsBackToAppActivation
    → Given a session with no PID but known terminalApp →
      activates by bundle ID

testFocusSessionReturnsFalseWhenNoMatch
    → Given a session with no PID and no terminalApp → returns false
```

## Self-Verification

1. `swift build` compiles
2. All tests pass
3. Manual test: start Terminal, call focusSession → Terminal comes to front
4. Manual test: isTerminalFocused returns true when Terminal is focused

## Notes
- This component gracefully degrades. Without Accessibility permissions,
  it still works — just can't target specific tabs/panes.
- Permission prompts should be deferred to the Settings/onboarding flow
  (Agent 10), not triggered automatically.
