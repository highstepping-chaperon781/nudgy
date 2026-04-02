import XCTest
@testable import Nudgy

final class HookInstallerTests: XCTestCase {
    private var testDir: URL!
    private var installer: HookInstaller!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nudgy-test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        installer = HookInstaller(port: 9847, settingsDir: testDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    func testInstallCreatesHooksInEmptySettings() throws {
        // Create empty settings file
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)

        try installer.install()

        let settings = try installer.readSettings()
        let hooks = settings["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks)

        for event in HookInstaller.hookedEvents {
            XCTAssertNotNil(hooks?[event], "Missing hook for \(event)")
        }
    }

    func testInstallPreservesExistingHooks() throws {
        let existing: [String: Any] = [
            "hooks": [
                "PreToolUse": [
                    ["hooks": [["type": "command", "command": "echo hello"]]]
                ]
            ]
        ]
        try writeJSON(existing, to: installer.settingsPath)

        try installer.install()

        let settings = try installer.readSettings()
        let hooks = settings["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks?["PreToolUse"], "User's own PreToolUse hook should be preserved")
    }

    func testInstallCleansUpLegacyNudgyPreToolUseHook() throws {
        // Simulate a previous Nudgy install that included PreToolUse
        let existing: [String: Any] = [
            "hooks": [
                "PreToolUse": [
                    ["hooks": [["type": "http", "url": "http://127.0.0.1:9847/event"]]]
                ]
            ]
        ]
        try writeJSON(existing, to: installer.settingsPath)

        try installer.install()

        let settings = try installer.readSettings()
        let hooks = settings["hooks"] as? [String: Any]
        XCTAssertNil(hooks?["PreToolUse"], "Nudgy's legacy PreToolUse hook should be removed")
    }

    func testInstallCleansUpLegacyButKeepsUserPreToolUseHook() throws {
        // User has their own command hook AND a legacy Nudgy HTTP hook on PreToolUse
        let existing: [String: Any] = [
            "hooks": [
                "PreToolUse": [
                    ["hooks": [["type": "command", "command": "echo hello"]]],
                    ["hooks": [["type": "http", "url": "http://127.0.0.1:9847/event"]]]
                ]
            ]
        ]
        try writeJSON(existing, to: installer.settingsPath)

        try installer.install()

        let settings = try installer.readSettings()
        let hooks = settings["hooks"] as? [String: Any]
        let preToolUseHooks = hooks?["PreToolUse"] as? [[String: Any]]
        XCTAssertEqual(preToolUseHooks?.count, 1, "Only user's hook should remain")
    }

    func testInstallPreservesExistingHooksForSameEvent() throws {
        let existing: [String: Any] = [
            "hooks": [
                "Stop": [
                    ["hooks": [["type": "command", "command": "echo done"]]]
                ]
            ]
        ]
        try writeJSON(existing, to: installer.settingsPath)

        try installer.install()

        let settings = try installer.readSettings()
        let stopHooks = (settings["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stopHooks?.count, 2, "Both user hook and Nudgy hook should exist")
    }

    func testInstallPreservesNonHookSettings() throws {
        let existing: [String: Any] = [
            "permissions": ["allow_all": true],
            "hooks": [:]
        ]
        try writeJSON(existing, to: installer.settingsPath)

        try installer.install()

        let settings = try installer.readSettings()
        XCTAssertNotNil(settings["permissions"])
    }

    func testInstallIsIdempotent() throws {
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)

        try installer.install()
        try installer.install()

        let settings = try installer.readSettings()
        let stopHooks = (settings["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stopHooks?.count, 1, "Should not duplicate hooks")
    }

    func testInstallUpdatesPortIfChanged() throws {
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)
        try installer.install()

        // Install with different port
        let installer2 = HookInstaller(port: 9848, settingsDir: testDir)
        try installer2.install()

        let settings = try installer2.readSettings()
        let stopHooks = (settings["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stopHooks?.count, 1)

        // Verify URL has new port
        let hooksList = stopHooks?.first?["hooks"] as? [[String: Any]]
        let url = hooksList?.first?["url"] as? String
        XCTAssertTrue(url?.contains("9848") == true)
    }

    func testUninstallRemovesOnlyOurHooks() throws {
        let existing: [String: Any] = [
            "hooks": [
                "Stop": [
                    ["hooks": [["type": "command", "command": "echo done"]]]
                ]
            ]
        ]
        try writeJSON(existing, to: installer.settingsPath)

        try installer.install()
        try installer.uninstall()

        let settings = try installer.readSettings()
        let stopHooks = (settings["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        XCTAssertEqual(stopHooks?.count, 1, "User hook should remain")
    }

    func testUninstallLeavesCleanState() throws {
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)
        try installer.install()
        try installer.uninstall()

        let settings = try installer.readSettings()
        XCTAssertNil(settings["hooks"], "Empty hooks key should be removed")
    }

    func testInstallCreatesBackup() throws {
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)
        try installer.install()

        let contents = try FileManager.default.contentsOfDirectory(at: testDir, includingPropertiesForKeys: nil)
        let backups = contents.filter { $0.lastPathComponent.hasPrefix("settings.json.backup.") }
        XCTAssertEqual(backups.count, 1)
    }

    func testInstallCreatesDirectoryIfMissing() throws {
        let newDir = testDir.appendingPathComponent("new-dir")
        let newInstaller = HookInstaller(port: 9847, settingsDir: newDir)
        try newInstaller.install()

        XCTAssertTrue(FileManager.default.fileExists(atPath: newDir.path))
        try? FileManager.default.removeItem(at: newDir)
    }

    func testInstallHandlesCorruptedSettingsFile() throws {
        try "not json".data(using: .utf8)!.write(to: installer.settingsPath)

        XCTAssertThrowsError(try installer.install()) { error in
            XCTAssertTrue(error is HookInstallerError)
        }
    }

    func testIsInstalledReturnsTrueAfterInstall() throws {
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)
        XCTAssertFalse(installer.isInstalled())

        try installer.install()
        XCTAssertTrue(installer.isInstalled())
    }

    func testIsInstalledReturnsFalseAfterUninstall() throws {
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)
        try installer.install()
        try installer.uninstall()
        XCTAssertFalse(installer.isInstalled())
    }

    func testVerifyReturnsTrueForValidInstall() throws {
        try "{}".data(using: .utf8)!.write(to: installer.settingsPath)
        try installer.install()
        XCTAssertTrue(installer.verify())
    }

    // MARK: - Helpers

    private func writeJSON(_ dict: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
        try data.write(to: url)
    }
}
