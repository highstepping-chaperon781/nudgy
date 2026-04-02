# Test Strategy

## Overview

Nudge uses a multi-layered testing approach: unit tests for each
component, integration tests for component interactions, E2E tests for
real-world scenarios, and performance tests for resource constraints.

## Test Pyramid

```
          ╱╲
         ╱  ╲       E2E Tests (5-10)
        ╱    ╲      Full round-trip HTTP → popup
       ╱──────╲
      ╱        ╲    Integration Tests (15-25)
     ╱          ╲   Component interactions
    ╱────────────╲
   ╱              ╲  Unit Tests (60-80)
  ╱                ╲ Individual functions & classes
 ╱──────────────────╲
```

## Unit Tests by Component

| Agent | Component | Test File | Test Count |
|-------|-----------|-----------|------------|
| 02 | HTTPServer | HTTPServerTests.swift | 10 |
| 03 | HookEvent decoding | HookEventTests.swift | 9 |
| 03 | SessionManager | SessionManagerTests.swift | 13 |
| 03 | AppState | AppStateTests.swift | 5 |
| 04 | PopupWindow | PopupWindowTests.swift | 12 |
| 05 | MenuBar | MenuBarTests.swift | 9 |
| 06 | SoundManager | SoundManagerTests.swift | 6 |
| 08 | HookInstaller | HookInstallerTests.swift | 17 |
| 09 | SmartSuppressor | SmartSuppressorTests.swift | 13 |
| 10 | Settings | SettingsTests.swift | 5 |
| **Total** | | | **~99** |

## Integration Tests

| Test | Components Involved | Verifies |
|------|---------------------|----------|
| HTTP → SessionManager | Server + State | Events flow from HTTP to state |
| SessionManager → AppState | State + UI | State changes update UI model |
| Event → Suppressor → Popup | State + Rules + UI | Suppression logic works in pipeline |
| HookInstaller round-trip | Installer + FS | Install/uninstall preserves user data |
| Permission → Escalation | State + Suppressor + Time | Stale permissions escalate |

## E2E Tests

| Scenario | Steps | Validates |
|----------|-------|-----------|
| Full session lifecycle | Start → work → permission → approve → stop → end | Complete happy path |
| Parallel sessions | 2 sessions, different states | Multi-session tracking |
| Stale session | Start, no events for 6min | Cleanup timer |
| Rapid-fire batching | 10 events in 5s | Suppression batching |
| Permission escalation | Permission, wait 3min | Escalation timer |

## Performance Tests

| Test | Target | Method |
|------|--------|--------|
| Event latency | < 50ms p99 | Measure 100 events |
| Memory idle | < 30MB | Check RSS after startup |
| Memory under load | < 50MB | 20 sessions, 1000 events |
| Server throughput | > 100 req/s | 1000 requests in 10s |
| Popup creation | < 50ms each | Create/destroy 100 panels |
| CPU idle | < 0.1% | Monitor for 60s with no events |

## Sanitizers

All tests run with:
- **Thread Sanitizer** (`--sanitize=thread`): Detects data races
- **Address Sanitizer** (`--sanitize=address`): Detects memory errors

## Mocking Strategy

| Component | Mock | Purpose |
|-----------|------|---------|
| WindowFocuser | MockWindowFocuser | Control isTerminalFocused() |
| NSScreen | (use real) | Multi-monitor test via NSScreen.screens |
| File system | Temp directory | Isolate HookInstaller tests |
| NSSound | (skip in tests) | SoundManager.isEnabled = false |
| HTTP | URLSession to localhost | Real HTTP for integration tests |

## Test Execution Order

```bash
# 1. Unit tests (fast, run first)
swift test --filter "NudgeTests" --skip "IntegrationTests|E2ETests|PerformanceTests"

# 2. Integration tests
swift test --filter "IntegrationTests"

# 3. E2E tests
swift test --filter "E2ETests"

# 4. Performance tests (slow, run last)
swift test --filter "PerformanceTests"

# 5. Full suite with thread sanitizer
swift test --sanitize=thread

# 6. Full suite with address sanitizer
swift test --sanitize=address
```

## Coverage Target

- **Line coverage**: > 80%
- **Branch coverage**: > 70%
- **Critical paths**: 100% (event processing, hook install/uninstall, popup show/dismiss)

## Test Environment

- macOS 13+ (Ventura)
- Swift 5.9+
- No external test dependencies (XCTest only)
- Tests must be runnable in CI (GitHub Actions macos-14 runner)
- Tests must not require user interaction or permissions grants
  (mock components that need Accessibility or Screen Recording)
