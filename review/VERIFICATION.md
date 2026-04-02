# Parent Agent Verification Protocol

## How Review Agents Work

Each review agent (REVIEW-ARCH, REVIEW-UI, REVIEW-INFRA) acts as a
quality gate between phases. They operate as follows:

### Step 1: Collect Completion Reports

Wait for all child agents to submit their COMPLETION_REPORT. Each report
lists files created, interfaces exposed, tests written, and known issues.

### Step 2: Code Review

For each child agent's output:

1. **Read every file** produced by the child agent
2. **Check against spec**: Does the implementation match the agent's .md spec?
3. **Check naming**: Are Swift naming conventions followed?
   - Types: PascalCase
   - Functions/variables: camelCase
   - Constants: camelCase (not SCREAMING_CASE)
4. **Check threading**: Are @MainActor, actor, and async/await used correctly?
5. **Check error handling**: Are errors properly caught and propagated?
6. **Check memory**: Are references weak where needed? Any retain cycles?

### Step 3: Run Tests

```bash
swift test --sanitize=thread
```

All tests from all child agents must pass. If any test fails:
1. Identify which child agent owns the failing test
2. Report the failure with the error message
3. That child agent must fix and re-submit

### Step 4: Integration Check

Verify that components compose correctly:

**REVIEW-ARCH verifies:**
- HTTPServer's delegate protocol matches what SessionManager expects
- HookEvent model decodes all JSON formats from IPC_PROTOCOL.md
- SessionManager publishes state to AppState on @MainActor

**REVIEW-UI verifies:**
- PopupContentView renders correctly with all NotificationStyle values
- MenuBarView reads from AppState and displays correct data
- SoundManager plays the right sound for each NotificationStyle
- No focus stealing (NSPanel flags are correct)

**REVIEW-INFRA verifies:**
- HookInstaller can install/uninstall without corrupting settings.json
- SmartSuppressor correctly uses WindowFocuser output
- WindowFocuser handles all known terminal app bundle IDs

### Step 5: Cross-Agent Dependency Check

Verify shared interfaces match:

```
Agent 02 (Server) exposes → HTTPServerDelegate.didReceive(event: HookEvent)
Agent 03 (State) consumes → HookEvent from Agent 02

Agent 03 (State) exposes → AppState with @Published properties
Agent 04 (Popup) consumes → NotificationItem from AppState
Agent 05 (Menu) consumes → AgentSession[] from AppState

Agent 07 (Focus) exposes → isTerminalFocused() -> Bool
Agent 09 (Suppress) consumes → isTerminalFocused from Agent 07
```

If any interface mismatch is found, the consumer agent must adapt
(the exposing agent's interface is the contract).

### Step 6: Approve or Reject

**Approve** if:
- All tests pass
- All checklist items verified
- No interface mismatches
- No threading issues detected

**Reject** if:
- Any test fails → send failure report to responsible agent
- Any checklist item fails → send specific feedback
- Interface mismatch → negotiate between agents, one must adapt
- Threading issue → agent must fix using proper Swift concurrency

## Rejection Protocol

When rejecting, the review agent produces:

```
## REJECTION REPORT — [Review Agent Name]

### Failed Items
1. Agent 04: testPanelDoesNotStealFocus FAILED
   Error: Terminal was not the frontmost app after popup show
   Fix: Verify styleMask includes .nonactivatingPanel

2. Agent 08: testInstallPreservesExistingHooks FAILED
   Error: User's PreToolUse hooks were overwritten
   Fix: Check merge algorithm — it should append, not replace

### Required Actions
- Agent 04: Fix focus stealing issue and re-run tests
- Agent 08: Fix merge algorithm and re-run all 17 tests

### Re-review Trigger
Submit new COMPLETION_REPORT after fixes. Review agent will re-run
the full checklist.
```

## Final Master Verification

After all three review agents approve, the Master Orchestrator runs:

1. Full test suite with both sanitizers
2. Build the .app bundle
3. Launch the app, send a test event via curl, verify popup appears
4. Check memory and CPU usage
5. If all pass → green light for distribution (Agent 12)

```bash
# Master verification script
set -e

echo "=== Building ==="
swift build -c release

echo "=== Running tests (thread sanitizer) ==="
swift test --sanitize=thread

echo "=== Running tests (address sanitizer) ==="
swift test --sanitize=address

echo "=== Packaging ==="
make package

echo "=== Launch test ==="
open -a Nudge.app
sleep 3

echo "=== Round-trip test ==="
curl -s -X POST http://127.0.0.1:9847/event \
  -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"Stop","session_id":"test","cwd":"/tmp/test"}'

echo "=== Checking memory ==="
MEM=$(ps -o rss= -p $(pgrep Nudge) | awk '{print $1/1024}')
echo "Memory: ${MEM}MB"
[ $(echo "$MEM < 30" | bc) -eq 1 ] || { echo "FAIL: Memory > 30MB"; exit 1; }

echo "=== All checks passed ==="
```
