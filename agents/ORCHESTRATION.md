# Agent Orchestration

## Agent Types

### Build Agents (01-12)
Each build agent is responsible for implementing one component. Every agent:
- Receives a detailed spec (its own .md file)
- Creates the Swift source files for its component
- Writes unit tests for its component
- Self-verifies by running tests before reporting done
- Outputs a COMPLETION_REPORT at the end listing files created, tests written,
  and any known issues

### Review/Parent Agents (REVIEW-ARCH, REVIEW-UI, REVIEW-INFRA)
Each review agent supervises a group of build agents. They:
- Wait for all child agents to complete
- Read the code produced by each child
- Run the combined test suite
- Verify integration between components (do they compose correctly?)
- Check for: naming consistency, threading correctness, memory leaks,
  error handling coverage
- Report issues back — child agents fix before gate passes

### Master Orchestrator
- Coordinates phase execution (Phases 1-5)
- Enforces gate criteria between phases
- Runs final E2E validation
- Produces the final build artifact

## Execution Rules

1. **Agents within the same phase run in parallel** where their dependencies
   allow. Phase 1 agents (01, 02, 03) all start simultaneously.

2. **Gates block the next phase.** Phase 2 does not start until REVIEW-ARCH
   approves Phase 1 output.

3. **Agents must self-test.** Every agent runs `swift test` for its own
   component before declaring completion. A build failure = incomplete.

4. **Review agents may reject.** If a review agent finds issues, the
   responsible build agent receives feedback and must fix + re-test.

5. **No agent writes outside its scope.** Agent 02 (HTTP Server) must not
   modify files owned by Agent 04 (Popup). Shared interfaces are defined
   in architecture docs and Agent 03 (State Engine).

## Communication Protocol Between Agents

Each agent produces output in a structured format:

```
## COMPLETION REPORT — Agent [ID]: [Name]

### Files Created
- Sources/Nudge/Server/HTTPServer.swift
- Tests/NudgeTests/HTTPServerTests.swift

### Public Interfaces Exposed
- `class HTTPServer { func start(); func stop() }`
- `protocol HTTPServerDelegate { func didReceive(event:) }`

### Dependencies Consumed
- `HookEvent` from Agent 03 (Data Models)

### Tests Written
- testServerStartsOnPort
- testServerReceivesValidJSON
- testServerRejectsInvalidToken
- testServerHandlesConcurrentConnections

### Test Results
All 4 tests passed.

### Known Issues
- None

### Notes for Review Agent
- Used NWListener, not swift-nio. Zero external dependencies.
```

## Phase Execution Detail

### Phase 1: Foundation
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Agent 01  │  │ Agent 02  │  │ Agent 03  │
│ Setup     │  │ Server    │  │ State     │
│           │  │           │  │           │
│ Creates:  │  │ Creates:  │  │ Creates:  │
│ Package   │  │ HTTP srv  │  │ Models    │
│ .swift    │  │ NWListenr │  │ Session   │
│ Info.plist│  │ Parser    │  │ Actor     │
│ .gitignor │  │ Tests     │  │ AppState  │
│ Targets   │  │           │  │ Tests     │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘
      │               │               │
      └───────────────┼───────────────┘
                      ▼
              ┌──────────────┐
              │ REVIEW-ARCH  │
              │ Verify:      │
              │ - Compiles   │
              │ - Tests pass │
              │ - Models OK  │
              │ - Server OK  │
              └──────┬───────┘
                     ▼
               Phase 2 begins
```

### Phase 2: UI Layer
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Agent 04  │  │ Agent 05  │  │ Agent 06  │
│ Popup     │  │ Menubar   │  │ Sound     │
│           │  │           │  │           │
│ NSPanel   │  │ NSStatus  │  │ NSSound   │
│ SwiftUI   │  │ Dropdown  │  │ Mapping   │
│ Animation │  │ Sessions  │  │ Volume    │
│ Stacking  │  │ History   │  │ Focus     │
│ Tests     │  │ Tests     │  │ Tests     │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘
      │               │               │
      └───────────────┼───────────────┘
                      ▼
              ┌──────────────┐
              │  REVIEW-UI   │
              │ Verify:      │
              │ - No focus   │
              │   stealing   │
              │ - Animations │
              │ - Dark/light │
              │ - Stacking   │
              └──────┬───────┘
                     ▼
               Phase 3 begins
```

### Phase 3: System Integration
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Agent 07  │  │ Agent 08  │  │ Agent 09  │
│ Focus     │  │ Hooks     │  │ Suppress  │
│           │  │           │  │           │
│ NSWorksp  │  │ JSON rw   │  │ Rules     │
│ AX API    │  │ Backup    │  │ Timing    │
│ App match │  │ Merge     │  │ Focus chk │
│ Tests     │  │ Uninstall │  │ Batching  │
│           │  │ Tests     │  │ Tests     │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘
      │               │               │
      └───────────────┼───────────────┘
                      ▼
              ┌──────────────┐
              │ REVIEW-INFRA │
              │ Verify:      │
              │ - Hook merge │
              │   is safe    │
              │ - Focus for  │
              │   all apps   │
              │ - Suppress   │
              │   rules work │
              └──────┬───────┘
                     ▼
               Phase 4 begins
```

### Phase 4: Settings
```
              ┌──────────┐
              │ Agent 10  │
              │ Settings  │
              │           │
              │ SwiftUI   │
              │ Prefs     │
              │ Persist   │
              │ Login     │
              │ Tests     │
              └─────┬─────┘
                    ▼
              Phase 5 begins
```

### Phase 5: Testing & Distribution
```
┌──────────┐  ┌──────────┐
│ Agent 11  │  │ Agent 12  │
│ Testing   │  │ Distro    │
│           │  │           │
│ E2E tests │  │ App bundl │
│ Integ     │  │ Signing   │
│ Perf      │  │ Notarize  │
│ Memory    │  │ DMG       │
│ Scenarios │  │ Homebrew  │
└─────┬─────┘  └─────┬─────┘
      │               │
      └───────┬───────┘
              ▼
      ┌──────────────┐
      │   MASTER      │
      │ Final gate:   │
      │ - All tests   │
      │ - .app works  │
      │ - Hook round  │
      │   trip OK     │
      │ - Perf OK     │
      └──────────────┘
```
