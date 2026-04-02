# Agent 08: Hook Installer

## Objective
Implement safe read/merge/write of AI coding agent hooks configuration into
`~/.claude/settings.json`, with backup, idempotency, and clean uninstall.

## Scope
- Read existing settings.json (or create empty)
- Backup before any modification
- Merge Nudge hooks without overwriting user hooks
- Idempotent install (re-running install doesn't duplicate hooks)
- Clean uninstall (removes only Nudge entries)
- Validation (re-read after write to verify integrity)
- Detect if hooks are already installed
- Handle missing ~/.claude/ directory

## Dependencies
- Agent 01: Project structure
- Agent 02: HTTP server port (used in hook URL)

## Files to Create

### Sources/Nudge/Services/HookInstaller.swift

```swift
import Foundation

enum HookInstallerError: Error, LocalizedError {
    case settingsFileCorrupted(String)
    case backupFailed(Error)
    case writeFailed(Error)
    case validationFailed
    case claudeDirectoryMissing

    var errorDescription: String? { ... }
}

final class HookInstaller {
    static let hookMarker = "nudge"  // Identifies our hooks
    let port: UInt16
    let settingsPath: URL
    let claudeDir: URL

    init(port: UInt16 = 9847) {
        self.port = port
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.claudeDir = home.appendingPathComponent(".claude")
        self.settingsPath = claudeDir.appendingPathComponent("settings.json")
    }

    /// Install hooks into settings.json
    func install() throws { ... }

    /// Remove only Nudge hooks from settings.json
    func uninstall() throws { ... }

    /// Check if hooks are already installed
    func isInstalled() -> Bool { ... }

    /// Verify hooks are correctly configured
    func verify() -> Bool { ... }

    // MARK: - Private

    /// Read and parse settings.json
    private func readSettings() throws -> [String: Any] { ... }

    /// Write settings.json atomically
    private func writeSettings(_ settings: [String: Any]) throws { ... }

    /// Create timestamped backup
    private func createBackup() throws -> URL { ... }

    /// Clean up old backups (keep last 5)
    private func pruneBackups() throws { ... }

    /// Build the hook entries for a given event type
    private func buildHookEntry(for eventType: String) -> [String: Any] { ... }
}
```

### Hook Entry Format

For each event type, we add:

```json
{
    "hooks": [
        {
            "type": "http",
            "url": "http://127.0.0.1:9847/event"
        }
    ]
}
```

### Merge Algorithm

```
1. Read existing settings.json → dict
2. Get or create dict["hooks"] → hooksDict
3. For each event type (Stop, Notification, StopFailure, SessionStart, SessionEnd):
   a. Get or create hooksDict[eventType] → array of hook groups
   b. Check if any hook group's hooks contain URL with "127.0.0.1:9847"
   c. If not found → append our hook group
   d. If found → update URL (in case port changed)
4. Write back
```

### Events We Hook Into

```swift
static let hookedEvents = [
    "Stop",
    "Notification",
    "StopFailure",
    "SessionStart",
    "SessionEnd",
]
```

### Uninstall Algorithm

```
1. Read settings.json → dict
2. For each event type in dict["hooks"]:
   a. Filter out hook groups where any hook URL contains "127.0.0.1:9847"
   b. If the event type array is now empty, remove the key entirely
3. If dict["hooks"] is now empty, remove "hooks" key entirely
4. Write back
```

## Tests to Write

### Tests/NudgeTests/HookInstallerTests.swift

```
testInstallCreatesHooksInEmptySettings
    → Empty settings.json → install → 5 event types added

testInstallPreservesExistingHooks
    → Settings has user hooks for PreToolUse → install → PreToolUse untouched

testInstallPreservesExistingHooksForSameEvent
    → Settings has user hooks for Stop → install → user hook still there,
      our hook appended alongside it

testInstallPreservesNonHookSettings
    → Settings has "permissions" key → install → "permissions" key unchanged

testInstallIsIdempotent
    → Install twice → only one set of Nudge hooks exists

testInstallUpdatesPortIfChanged
    → Install with port 9847, then install with port 9848 →
      URL updated to 9848, not duplicated

testUninstallRemovesOnlyOurHooks
    → Install, add user hook, uninstall → user hook remains

testUninstallLeavesCleanState
    → Install, uninstall → settings.json has no empty "hooks" key

testInstallCreatesBackup
    → Install → backup file exists with timestamp

testInstallKeepsLast5Backups
    → Install 7 times → only 5 backup files remain

testInstallCreatesClaudeDirectoryIfMissing
    → ~/.claude doesn't exist → install creates it

testInstallHandlesCorruptedSettingsFile
    → settings.json contains invalid JSON → throws settingsFileCorrupted

testIsInstalledReturnsTrueAfterInstall
    → Install → isInstalled() returns true

testIsInstalledReturnsFalseAfterUninstall
    → Install, uninstall → isInstalled() returns false

testVerifyReturnsTrueForValidInstall
    → Install → verify() returns true

testVerifyReturnsFalseIfHooksMissing
    → Manually remove one event type → verify() returns false

testAtomicWrite
    → Write large settings → kill process mid-write (simulate) →
      original file is intact
```

### Test Helpers

Use a temporary directory for all tests (not real ~/.claude):

```swift
override func setUp() {
    testDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: testDir, ...)
    installer = HookInstaller(port: 9847, settingsDir: testDir)
}

override func tearDown() {
    try? FileManager.default.removeItem(at: testDir)
}
```

## Self-Verification

1. `swift build` compiles
2. All 17 tests pass
3. Install + uninstall cycle leaves settings.json identical to original
4. JSON output is pretty-printed and sorted (readable by humans)
5. Backup files are created with correct timestamps

## Safety Guarantees
- NEVER overwrites user hooks
- ALWAYS creates backup before modifying
- Atomic writes prevent corruption on crash
- Idempotent — safe to run multiple times
- Clean uninstall — no orphaned entries
