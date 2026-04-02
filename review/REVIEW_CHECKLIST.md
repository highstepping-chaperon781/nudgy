# Review Checklists

## REVIEW-ARCH (Phase 1 Gate)

### Compilation
- [ ] `swift build` succeeds with zero errors
- [ ] `swift build` produces zero warnings
- [ ] `swift test` discovers and runs all test targets

### Project Structure
- [ ] Package.swift has correct platform (.macOS(.v13))
- [ ] No external dependencies (except test utilities)
- [ ] Directory structure matches Agent 01 specification
- [ ] All files are in the correct directories

### HTTP Server (Agent 02)
- [ ] Binds to 127.0.0.1 only (not 0.0.0.0)
- [ ] Responds to POST with 200 OK
- [ ] Rejects non-POST with 405
- [ ] Rejects invalid JSON with 400
- [ ] Handles concurrent connections without crash
- [ ] Releases port on stop()
- [ ] All 10 unit tests pass

### Data Models (Agent 03)
- [ ] HookEvent decodes all JSON payloads from IPC_PROTOCOL.md
- [ ] SessionState enum has correct priority ordering
- [ ] SessionManager is a Swift `actor` (not class)
- [ ] AppState is `@MainActor @Observable`
- [ ] RingBuffer enforces capacity limit
- [ ] AnyCodable handles all JSON types
- [ ] All 27 unit tests pass

### Integration
- [ ] Server delegate correctly creates HookEvent from JSON
- [ ] SessionManager correctly updates session state from events
- [ ] AppState reflects session changes on @MainActor
- [ ] No threading issues (run with --sanitize=thread)

---

## REVIEW-UI (Phase 2 Gate)

### Floating Popup (Agent 04)
- [ ] Uses NSPanel (not NSWindow)
- [ ] styleMask includes .nonactivatingPanel
- [ ] becomesKeyOnlyIfNeeded is true
- [ ] Does NOT steal focus from any app (manual test)
- [ ] level is .floating
- [ ] collectionBehavior includes .canJoinAllSpaces
- [ ] collectionBehavior includes .fullScreenAuxiliary
- [ ] collectionBehavior includes .ignoresCycle
- [ ] Stacks up to 4 panels without overlap
- [ ] 5th panel dismisses oldest informational
- [ ] Auto-dismiss works with configurable timeout
- [ ] Persistent notifications don't auto-dismiss
- [ ] Slide-in animation works (or fade if Reduced Motion)
- [ ] Slide-out animation works on dismiss
- [ ] Uses .ultraThinMaterial (adapts to dark/light)
- [ ] Accent bar color matches notification style
- [ ] Close button appears on hover
- [ ] VoiceOver announcement posted on show
- [ ] All 12 unit tests pass

### Menubar (Agent 05)
- [ ] NSStatusItem created with variable length
- [ ] Icon updates based on AppState changes
- [ ] Priority ordering: permission > error > question > working > idle
- [ ] Dropdown shows active sessions with correct state
- [ ] Dropdown shows recent events
- [ ] Permission rows have action buttons
- [ ] Popover dismisses when clicking outside
- [ ] Works in both dark and light mode
- [ ] All 9 unit tests pass

### Sound (Agent 06)
- [ ] All 5 system sounds exist and play without error
- [ ] Volume control applies correctly
- [ ] Disabled flag prevents sound playback
- [ ] Thread-safe (no races on concurrent play)
- [ ] All 6 unit tests pass

### Cross-Component
- [ ] Popup, menubar, and sound all respond to the same AppState changes
- [ ] No duplicate notifications (one event = one popup + one sound)
- [ ] Dark mode renders correctly in popup AND menubar dropdown

---

## REVIEW-INFRA (Phase 3 Gate)

### Window Focus (Agent 07)
- [ ] Known apps list includes all 8 terminal/editors
- [ ] isTerminalFocused() returns true when Terminal is front
- [ ] isTerminalFocused() returns false for non-terminal apps
- [ ] focusSession() activates the correct app
- [ ] Graceful degradation without Accessibility permission
- [ ] All tests pass

### Hook Installer (Agent 08)
- [ ] NEVER overwrites user hooks — verified with complex scenarios
- [ ] Creates backup before every modification
- [ ] Backup pruning keeps last 5 only
- [ ] Idempotent install (running twice doesn't duplicate)
- [ ] Port change updates URL without duplicating
- [ ] Uninstall removes only our hooks
- [ ] Uninstall leaves clean JSON (no empty objects/arrays)
- [ ] Creates ~/.claude/ directory if missing
- [ ] Handles corrupted settings.json gracefully
- [ ] Atomic writes prevent corruption
- [ ] All 17 unit tests pass
- [ ] Integration test: install → verify → uninstall → verify

### Smart Suppression (Agent 09)
- [ ] Permission requests NEVER suppressed (100% verified)
- [ ] Errors NEVER suppressed
- [ ] Terminal focused → informational suppressed
- [ ] Fast completion → suppressed
- [ ] Recent interaction → suppressed
- [ ] Rapid-fire → batched
- [ ] Escalation after 2 minutes of pending permission
- [ ] Configurable thresholds applied correctly
- [ ] Different sessions tracked independently
- [ ] All 13 unit tests pass

---

## MASTER (Final Gate)

### Full Test Suite
- [ ] `swift test` — all tests pass (unit + integration + E2E)
- [ ] `swift test --sanitize=thread` — no warnings
- [ ] `swift test --sanitize=address` — no warnings

### App Bundle
- [ ] .app bundle created with correct Info.plist
- [ ] LSUIElement = true (no Dock icon)
- [ ] App launches without crash
- [ ] Menubar icon appears
- [ ] HTTP server starts on configured port

### Round-Trip Test
- [ ] curl POST to server → popup appears → auto-dismisses
- [ ] Permission event → persistent popup with actions
- [ ] Multiple sessions → menubar shows all

### Performance
- [ ] Memory idle: < 30MB
- [ ] CPU idle: < 0.1%
- [ ] Event latency: < 50ms
- [ ] Binary size: < 5MB

### Distribution (if Agent 12 complete)
- [ ] Code signed (if signing identity available)
- [ ] DMG mounts correctly
- [ ] App runs from /Applications after drag-install
