# Nudge — Master Orchestration Plan

## Vision

A native macOS companion app that monitors AI coding agent sessions and
provides floating GUI notifications when an agent finishes work, needs
permissions, or asks questions. Initially supports Claude Code (CLI, VS Code, Desktop App) with
architecture designed to support additional agents (Aider, Codex CLI,
Cursor background agents, etc.) in the future.

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI + AppKit hybrid (NSPanel for floating windows)
- **HTTP Server**: NWListener (Network.framework) — zero dependencies
- **Target**: macOS 13+ (Ventura)
- **Distribution**: DMG + Homebrew Cask
- **Dependencies**: Sparkle (auto-updates only)

## Agent Hierarchy

```
                    ┌─────────────────────┐
                    │   MASTER ORCHESTRATOR │
                    │   (This Plan)        │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                 ▼
     ┌────────────┐   ┌────────────┐   ┌────────────────┐
     │ REVIEW-ARCH │   │ REVIEW-UI  │   │ REVIEW-INFRA   │
     │ (Parent)    │   │ (Parent)   │   │ (Parent)       │
     └──────┬─────┘   └──────┬─────┘   └──────┬─────────┘
            │                │                  │
     ┌──────┼──────┐   ┌────┼────┐    ┌───────┼────────┐
     ▼      ▼      ▼   ▼    ▼    ▼    ▼       ▼        ▼
   [01]   [02]   [03] [04] [05] [06] [07]    [08]    [09]
  Setup  Server State  Pop  Menu Snd  Focus  Hooks  Suppress
                                                       │
                                              ┌────────┼────────┐
                                              ▼        ▼        ▼
                                            [10]     [11]     [12]
                                           Settings  Test    Distro
```

## Agent Execution Order

### Phase 1: Foundation (agents run in parallel)
| Agent | ID | Depends On | Estimated Time |
|-------|----|------------|----------------|
| Project Setup | 01 | — | 30 min |
| HTTP Server | 02 | — | 2 hours |
| Data Models & State Engine | 03 | — | 2 hours |

**Gate 1**: REVIEW-ARCH parent agent verifies all 3 compile and pass unit tests.

### Phase 2: UI Layer (agents run in parallel)
| Agent | ID | Depends On | Estimated Time |
|-------|----|------------|----------------|
| Floating Popup Window | 04 | 01, 03 | 3 hours |
| Menubar Icon & Dropdown | 05 | 01, 03 | 2 hours |
| Sound System | 06 | 01 | 1 hour |

**Gate 2**: REVIEW-UI parent agent verifies all UI elements render correctly,
animations are smooth, and no focus-stealing occurs.

### Phase 3: System Integration (agents run in parallel)
| Agent | ID | Depends On | Estimated Time |
|-------|----|------------|----------------|
| Window Focus Detection | 07 | 01, 03 | 2 hours |
| Hook Installer | 08 | 01, 02 | 2 hours |
| Smart Notification Suppression | 09 | 03, 04 | 2 hours |

**Gate 3**: REVIEW-INFRA parent agent verifies hooks install/uninstall cleanly,
focus detection works across Terminal/iTerm2/VS Code, and suppression logic
prevents notification fatigue.

### Phase 4: Polish & Settings (sequential)
| Agent | ID | Depends On | Estimated Time |
|-------|----|------------|----------------|
| Settings & Preferences | 10 | 04, 05, 06, 09 | 2 hours |

### Phase 5: Testing & Distribution (parallel)
| Agent | ID | Depends On | Estimated Time |
|-------|----|------------|----------------|
| Integration & E2E Testing | 11 | All above | 3 hours |
| Build & Distribution | 12 | All above | 2 hours |

**Final Gate**: Master orchestrator runs full test suite, verifies .app bundle,
tests hook round-trip, and validates notarization.

## Success Criteria

1. `curl -X POST http://localhost:9847/event -d '{"hook_event_name":"Stop"}'`
   triggers a floating popup + sound within 200ms
2. Popup does NOT steal focus from any app
3. Multiple concurrent sessions tracked independently
4. Hooks install/uninstall without corrupting existing settings.json
5. Memory < 30MB idle, CPU < 0.1% idle
6. All unit tests pass, integration tests pass
7. .app bundle is signed, notarized, and launches correctly from DMG

## File Index

- `architecture/` — System design, data models, IPC protocol
- `agents/` — Detailed spec for each build agent (01-12) + orchestration doc
- `testing/` — Test strategy, unit/integration/e2e test specs
- `review/` — Review checklists and parent agent verification protocols
