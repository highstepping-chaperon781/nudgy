# System Design

## Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Nudgy.app                      │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ MenuBarManager│  │  HTTPServer  │  │ PopupManager  │  │
│  │ (NSStatusItem)│  │ (NWListener) │  │ (NSPanel pool)│  │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘  │
│         │                 │                   │          │
│         │   ┌─────────────▼──────────────┐    │          │
│         └──►│     SessionManager         │◄───┘          │
│             │     (Swift Actor)          │               │
│             └─────────────┬──────────────┘               │
│                           │                              │
│             ┌─────────────▼──────────────┐               │
│             │       AppState             │               │
│             │   (@Observable @MainActor) │               │
│             └─────────────┬──────────────┘               │
│                           │                              │
│  ┌──────────────┐  ┌─────▼────────┐  ┌───────────────┐  │
│  │ WindowFocuser│  │ SmartSuppress│  │  SoundManager │  │
│  │ (AX API)     │  │ (Rules Eng.) │  │  (NSSound)    │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │              HookInstaller                        │    │
│  │  (Reads/merges ~/.claude/settings.json)           │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
          ▲
          │ HTTP POST http://127.0.0.1:9847/event
          │
┌─────────┴───────────────────────────────────────────────┐
│  AI coding agent Hooks (any frontend: CLI / VS Code / App)   │
│                                                          │
│  Stop → POST {hook_event_name: "Stop", session_id: ...}  │
│  Notification → POST {hook_event_name: "Notification"...} │
│  StopFailure → POST {hook_event_name: "StopFailure"...}   │
└──────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### HTTPServer
- Listens on `127.0.0.1:9847` (TCP, NWListener)
- Parses minimal HTTP/1.1 (POST only, JSON body)
- Validates shared secret token (X-Nudgy-Token header)
- Deserializes JSON into `HookEvent` structs
- Forwards events to SessionManager
- Responds with 200 OK immediately (non-blocking)

### SessionManager (Swift Actor)
- Thread-safe state container for all active sessions
- Maintains `[String: AgentSession]` map keyed by session_id
- Processes events: updates session state, manages lifecycle
- Detects stale sessions (no events for 5 min) and cleans up
- Publishes state changes to AppState on @MainActor

### AppState (@Observable, @MainActor)
- SwiftUI-observable state object
- Drives all UI: menubar, popups, settings
- Receives processed state from SessionManager

### PopupManager
- Manages a pool of up to 4 NSPanel instances
- Handles stacking, positioning, and animation
- Each panel: borderless, non-activating, floating level
- Content rendered via NSHostingView wrapping SwiftUI views
- Auto-dismiss timers per panel (configurable)
- Click handlers: dismiss, focus terminal, approve/deny

### MenuBarManager
- NSStatusItem with dynamic icon (SF Symbols)
- Icon state reflects aggregate session status
- Dropdown panel (NSPopover or custom NSPanel) with:
  - Active sessions list with inline actions
  - Recent event history (last 10)
  - Quick settings toggles
  - Quit button

### SmartSuppressor
- Rule engine that decides whether to show/suppress a notification
- Rules:
  1. Terminal focused → suppress
  2. Completion < 5s → suppress
  3. Rapid-fire (3+ events in 10s) → batch
  4. Recent user interaction (< 10s) → suppress
  5. Permission requests → NEVER suppress
- Configurable thresholds via Settings

### WindowFocuser
- Finds and activates terminal/editor windows by session PID
- Uses NSWorkspace for app activation
- Uses Accessibility API for specific window/tab targeting
- Fallback chain: PID → window title → app activation

### SoundManager
- Plays system sounds via NSSound
- Maps event types to sound names (configurable)
- Respects macOS Do Not Disturb / Focus modes
- Volume: independent slider, defaults to 50% of system

### HookInstaller
- Reads ~/.claude/settings.json (or creates it)
- Merges Nudgy hooks without overwriting user hooks
- Idempotent: detects existing installation via marker
- Backup before modify (timestamped .backup files)
- Clean uninstall: removes only Nudgy entries

## Threading Model

```
Main Thread (@MainActor)
  ├── SwiftUI rendering (MenuBarExtra, PopupContentView, SettingsView)
  ├── NSPanel management (show/hide/animate)
  ├── NSStatusItem updates
  └── AppState property changes

Global Dispatch Queue (background)
  ├── NWListener connection handling
  ├── HTTP parsing
  └── JSON deserialization

SessionManager Actor (isolated)
  ├── Session state mutations
  ├── Stale session cleanup timer
  └── Event deduplication
```

## Port Selection: 9847

- Not in IANA registered range for common services
- Mnemonic: 9-8-4-7 → no conflict with common dev ports
- Configurable via Settings if user has a conflict
- On port conflict at startup: try 9847, 9848, 9849; alert user if all fail

## Security

- Bind to 127.0.0.1 only (never 0.0.0.0)
- Shared secret token generated on first launch, stored in Keychain
- Token injected into hook config automatically
- Validate token on every request; reject with 401 if invalid
- Rate limit: max 100 requests/second per source
- No sensitive data logged (commands may contain secrets)
