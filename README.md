# Nudge

A native macOS menu bar app that notifies you when your AI coding agent finishes work, needs permissions, or asks a question — without stealing focus from your terminal.

Currently supports [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI, VS Code, Desktop App), with architecture designed for additional agents (Aider, Codex CLI, Cursor, etc.) in the future.

## Why Nudge?

When you're running an AI coding agent in the background, you don't want to keep checking if it's done. Nudge watches your agent sessions and shows unobtrusive floating notifications so you can focus on other work.

- **Floating popups** that don't steal focus from your terminal or editor
- **Menu bar icon** with live session status at a glance
- **Smart suppression** to avoid notification fatigue during rapid-fire events
- **Sound alerts** mapped to event types (configurable)
- **Multi-session tracking** with color-coded sessions
- **Zero external dependencies** — built entirely on macOS system frameworks

## Requirements

- macOS 14.0+ (Sonoma or later)
- Swift 5.9+

## Installation

### From Source

```bash
git clone https://github.com/Hamma111/nudge.git
cd nudge
make build
```

### Run

```bash
make run
```

### Create .app Bundle

```bash
make package
```

The app bundle will be at `.build/release/Nudge.app`.

## How It Works

Nudge runs a lightweight HTTP server on `127.0.0.1:9847` that listens for events from AI coding agent hooks. When Claude Code fires a hook event (task complete, permission needed, error, etc.), Nudge receives the JSON payload and shows an appropriate notification.

```
Claude Code ──hook──▶ POST http://127.0.0.1:9847/event ──▶ Nudge ──▶ Floating Popup
```

### Setting Up Hooks

Nudge can automatically install the required hooks into your `~/.claude/settings.json`. You can also configure them manually:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
          }
        ]
      }
    ]
  }
}
```

See [IPC Protocol](architecture/IPC_PROTOCOL.md) for the full list of supported events and payloads.

### Supported Events

| Event | What Happens |
|-------|-------------|
| **Stop** | Agent finished responding — success popup |
| **Notification** (permission) | Agent needs permission — warning popup |
| **Notification** (idle) | Agent is asking a question — question popup |
| **StopFailure** | Error during generation — error popup |
| **SessionStart** | New session started — tracked silently |
| **SessionEnd** | Session ended — cleaned up silently |

## Building

```bash
make build      # Release build
make debug      # Debug build
make test       # Run all tests
make clean      # Clean build artifacts
make package    # Create .app bundle
make dmg        # Create distributable DMG
```

For code signing and notarization (distribution):

```bash
SIGNING_IDENTITY="Developer ID Application: ..." make sign
APPLE_ID="..." TEAM_ID="..." APP_PASSWORD="..." make notarize
```

## Architecture

Nudge is built with SwiftUI + AppKit hybrid using zero external dependencies:

- **HTTP Server** — `NWListener` (Network.framework) on localhost
- **Session Manager** — Swift Actor for thread-safe state management
- **Floating Popups** — `NSPanel` pool (max 3 visible, auto-dismiss)
- **Menu Bar** — `NSStatusItem` with dynamic status icon
- **Smart Suppression** — Rules engine to prevent notification fatigue
- **Window Focus** — Detects active terminal/editor to suppress when visible

See the [architecture](architecture/) directory for detailed design docs.

## Contributing

Contributions are welcome! Please read the [Contributing Guide](CONTRIBUTING.md) before submitting a pull request.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
