# Agent 05: Menubar Icon & Dropdown

## Objective
Implement the menubar status item with dynamic icon states and a rich
dropdown panel showing active sessions, recent events, and quick actions.

## Scope
- NSStatusItem with SF Symbol icon
- Icon color/state changes based on aggregate session state
- Dropdown panel (NSPopover or NSMenu with SwiftUI views)
- Active sessions list with status indicators
- Recent event history (last 10)
- Quick actions (test notification, quit)
- Badge indicator for pending actions

## Dependencies
- Agent 01: Project structure
- Agent 03: AppState, AgentSession, SessionState models

## Files to Create

### Sources/Nudge/UI/MenuBarManager.swift

```swift
final class MenuBarManager {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        setupStatusItem()
    }

    func updateIcon() {
        // Read appState.statusIcon and appState.iconColor
        // Update statusItem.button.image and tint
    }

    // MARK: - Private

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        // Configure button with SF Symbol
        // Set action to toggle popover
    }

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(appState: appState)
        )
        popover.show(
            relativeTo: statusItem.button!.bounds,
            of: statusItem.button!,
            preferredEdge: .minY
        )
        self.popover = popover
    }
}
```

### Sources/Nudge/UI/MenuBarView.swift

```swift
struct MenuBarView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()

            // Active sessions
            sessionsSection

            Divider()

            // Recent events
            recentEventsSection

            Divider()

            // Footer actions
            footerSection
        }
        .frame(width: 300)
    }
}
```

### Icon State Mapping

| Aggregate State | SF Symbol | Color |
|-----------------|-----------|-------|
| No sessions | `circle` | .secondary |
| All idle | `circle.fill` | .blue |
| Any working | `circle.fill` (pulsing) | .blue |
| Any permission | `exclamationmark.triangle.fill` | .yellow |
| Any question | `questionmark.circle.fill` | .blue |
| Any error | `xmark.circle.fill` | .red |

Priority: permission > error > question > working > idle > none.

### Session Row in Dropdown

```
╭────────────────────────────────────────────╮
│  ● easychef-backend          Terminal      │
│    ⚠ Permission pending · 45s ago          │
│    [Approve]  [Deny]  [Focus →]            │
╰────────────────────────────────────────────╯
```

Each row shows:
- Colored dot (session accent color)
- Project name
- Terminal app name
- Current state + relative time
- Inline action buttons for actionable states

### Event History Row

```
│  ✓  2:34 PM  Output complete (easychef)   │
│  ⚠  2:31 PM  Permission approved (infra)  │
│  ?  2:28 PM  Question answered (easychef)  │
```

## Tests to Write

### Tests/NudgeTests/MenuBarTests.swift

```
testStatusItemCreated
    → Verify NSStatusBar.system has our status item

testIconReflectsNoSessions
    → AppState has 0 sessions → icon is "circle", color secondary

testIconReflectsPermissionPending
    → AppState has session with .waitingPermission → icon is warning, yellow

testIconReflectsError
    → AppState has session with .error → icon is xmark, red

testIconPriorityOrdering
    → One session idle, one permission → icon shows permission (higher priority)

testDropdownShowsActiveSessions
    → 3 sessions in AppState → dropdown lists all 3

testDropdownShowsRecentEvents
    → 5 events in AppState → dropdown shows last 5

testDropdownSessionRowShowsActions
    → Session in .waitingPermission → row has Approve/Deny buttons

testPopoverDismissesOnClickOutside
    → behavior is .transient → verify popover dismisses
```

## Self-Verification

1. `swift build` compiles
2. All tests pass
3. Menubar icon renders correctly in both dark and light mode
4. Dropdown popover appears below menubar icon
5. Session rows display correct state indicators
