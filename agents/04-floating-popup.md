# Agent 04: Floating Popup Window

## Objective
Implement the floating notification popup system using NSPanel + SwiftUI
content views. This is the primary user-facing component — it must look
native, animate smoothly, and NEVER steal focus.

## Scope
- PopupWindowController (manages NSPanel lifecycle)
- PopupContentView (SwiftUI view rendered inside NSPanel)
- Notification stacking (up to 4 visible)
- Slide-in / slide-out animations
- Auto-dismiss with configurable timeout
- Click handlers (dismiss, focus terminal)
- Dark/light mode support via `.ultraThinMaterial`
- Multi-monitor positioning

## Dependencies
- Agent 01: Project structure
- Agent 03: NotificationItem, NotificationStyle, NotificationAction models

## Files to Create

### Sources/Nudge/UI/PopupWindowController.swift

```swift
final class PopupWindowController {
    private var activePanels: [(panel: NSPanel, item: NotificationItem)] = []
    private var dismissTimers: [UUID: Task<Void, Never>] = [:]
    private let maxVisible: Int = 4
    private let stackSpacing: CGFloat = 8
    private let edgePadding: CGFloat = 16

    /// Show a new notification popup
    func show(_ item: NotificationItem) { ... }

    /// Dismiss a specific notification
    func dismiss(id: UUID) { ... }

    /// Dismiss all notifications
    func dismissAll() { ... }

    // MARK: - Private

    /// Create and configure an NSPanel
    private func createPanel(for item: NotificationItem) -> NSPanel { ... }

    /// Calculate position for a new panel in the stack
    private func calculatePosition(at index: Int) -> NSPoint { ... }

    /// Reposition remaining panels after one is dismissed
    private func repositionPanels(animated: Bool) { ... }

    /// Animate panel entrance (slide from right)
    private func animateIn(_ panel: NSPanel, to position: NSPoint) { ... }

    /// Animate panel exit (slide to right + fade)
    private func animateOut(_ panel: NSPanel, completion: @escaping () -> Void) { ... }
}
```

### NSPanel Configuration (Critical)

```swift
private func createPanel(for item: NotificationItem) -> NSPanel {
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 396, height: 116),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )

    // CRITICAL: These flags prevent focus stealing
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isMovableByWindowBackground = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.hidesOnDeactivate = false

    // Visible on all Spaces, above full-screen apps
    panel.collectionBehavior = [
        .canJoinAllSpaces,
        .stationary,
        .fullScreenAuxiliary,
        .ignoresCycle,
    ]

    panel.animationBehavior = .utilityWindow

    // SwiftUI content
    let contentView = PopupContentView(item: item, onDismiss: { ... }, onAction: { ... })
    panel.contentView = NSHostingView(rootView: contentView)

    return panel
}
```

### Sources/Nudge/UI/PopupContentView.swift

```swift
struct PopupContentView: View {
    let item: NotificationItem
    let onDismiss: () -> Void
    let onAction: (NotificationAction) -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar (left edge)
            Rectangle()
                .fill(item.style.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                // Header row: icon + title + close button
                HStack {
                    Image(systemName: item.style.icon)
                        .foregroundStyle(item.style.color)
                        .font(.system(size: 14, weight: .semibold))

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(item.projectName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if isHovered {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Message
                Text(item.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Action buttons (for permission requests)
                if !item.actions.isEmpty {
                    HStack(spacing: 8) {
                        Spacer()
                        ForEach(item.actions, id: \.label) { action in
                            Button(action.label) {
                                onAction(action)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(width: 380, height: heightForItem)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .onHover { isHovered = $0 }
    }

    private var heightForItem: CGFloat {
        item.actions.isEmpty ? 80 : 110
    }
}
```

### Animation Details

**Slide-in (entrance)**:
- Panel starts 30pt to the right of final position, alpha 0
- Animates to final position with ease-out timing, 0.3s duration
- Alpha animates to 1.0 concurrently

**Slide-out (dismissal)**:
- Panel slides 30pt to the right
- Alpha animates to 0
- Duration: 0.25s, ease-in timing
- On completion: `panel.orderOut(nil)`, remove from activePanels

**Stack reposition**:
- When a panel is dismissed from the middle of the stack,
  panels below it slide up to fill the gap
- Spring animation: duration 0.3s, damping 0.85

### Stacking Logic

```
Screen edge (right)
                          ╭──────────────────────╮  ← Index 0 (newest)
                  16px →  │ ⚠ Permission needed   │
                          ╰──────────────────────╯
                   8px gap
                          ╭──────────────────────╮  ← Index 1
                          │ ✓ Claude finished     │
                          ╰──────────────────────╯
                   8px gap
                          ╭──────────────────────╮  ← Index 2
                          │ ? Claude asks...      │
                          ╰──────────────────────╯
                                                     ← Index 3 max

Position: top-right, 16px from right edge, 16px below menubar.
Priority ordering: permission > error > question > info.
If 5th notification arrives, oldest informational one is auto-dismissed.
```

## Tests to Write

### Tests/NudgeTests/PopupWindowTests.swift

```
testPanelIsNonActivating
    → Verify styleMask contains .nonactivatingPanel
    → Verify becomesKeyOnlyIfNeeded is true

testPanelDoesNotStealFocus
    → Activate another app (Terminal)
    → Show popup
    → Verify Terminal is still the active app (NSWorkspace.shared.frontmostApplication)

testPanelAppearsOnAllSpaces
    → Verify collectionBehavior contains .canJoinAllSpaces

testStackingUpToFourPanels
    → Show 4 notifications
    → Verify 4 panels exist and don't overlap

testOldestDismissedWhenFifthArrives
    → Show 5 notifications
    → Verify only 4 are visible, oldest info one was removed

testAutoDismissAfterTimeout
    → Show notification with 2s timeout
    → Wait 3s
    → Verify panel is gone

testPersistentNotificationDoesNotAutoDismiss
    → Show permission notification (autoDismiss: nil)
    → Wait 10s
    → Verify panel is still visible

testDismissAnimatesOut
    → Show notification, dismiss it
    → Verify panel.alphaValue reaches 0

testMultiMonitorPositioning
    → Mock NSScreen with two screens
    → Verify popup appears on the correct screen

testDarkModeRendering
    → Set effective appearance to dark
    → Verify .ultraThinMaterial is used

testLightModeRendering
    → Set effective appearance to light
    → Verify rendering is correct

testHoverRevealsCloseButton
    → Simulate hover state
    → Verify close button visibility
```

## Self-Verification

1. `swift build` compiles cleanly
2. All popup tests pass
3. **Manual verification** (if possible in CI):
   - Show a popup → it appears in top-right
   - Click on Terminal → Terminal stays focused (popup didn't steal focus)
   - Wait 6s → popup auto-dismisses
   - Show 4 popups → they stack without overlap
4. No memory leaks (NSPanel references properly cleaned up on dismiss)

## Accessibility Requirements
- VoiceOver: Each popup must post `NSAccessibility.Notification.announcementRequested`
  with the title and message text when it appears
- Reduced Motion: If `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`,
  skip slide animations, use simple fade (0.2s)
- High Contrast: Increase border opacity if
  `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast`
