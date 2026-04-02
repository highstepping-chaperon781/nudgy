import Cocoa
import ApplicationServices

/// Detects and activates terminal/editor windows for AI coding agent sessions.
final class WindowFocuser {

    /// Known terminal/editor bundle IDs.
    static let knownApps: [String: String] = [
        "com.apple.Terminal":                "Terminal",
        "com.googlecode.iterm2":             "iTerm2",
        "net.kovidgoyal.kitty":              "Kitty",
        "com.mitchellh.ghostty":             "Ghostty",
        "dev.warp.Warp-Stable":              "Warp",
        "com.microsoft.VSCode":              "VS Code",
        "com.todesktop.230313mzl4w4u92":     "Cursor",
        "com.anthropic.claudedesktop":       "Claude Desktop",
    ]

    /// Focus the window running the given session.
    /// Returns true if an app was successfully activated.
    func focusSession(_ session: AgentSession) -> Bool {
        // Strategy 1: Activate by PID
        if let pid = session.terminalPID, activateByPID(pid) {
            return true
        }

        // Strategy 2: Activate by known terminal app name
        if let appName = session.terminalApp,
           let bundleId = Self.knownApps.first(where: { $0.value == appName })?.key,
           activateByBundleId(bundleId) {
            return true
        }

        // Strategy 3: Activate any running known terminal
        return activateAnyKnownTerminal()
    }

    /// Check if any known terminal/editor is the frontmost app.
    func isTerminalFocused() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        return Self.knownApps.keys.contains(frontApp.bundleIdentifier ?? "")
    }

    /// Detect which terminal app owns a given PID (by walking up the process tree).
    func detectTerminalApp(pid: pid_t?) -> (bundleId: String, name: String)? {
        guard let pid = pid else { return nil }

        // Check running apps for this PID
        for app in NSWorkspace.shared.runningApplications {
            if app.processIdentifier == pid,
               let bundleId = app.bundleIdentifier,
               let name = Self.knownApps[bundleId] {
                return (bundleId, name)
            }
        }

        // Walk up the process tree
        var currentPID = pid
        for _ in 0..<10 {
            let parentPID = getParentPID(currentPID)
            if parentPID <= 1 { break }

            for app in NSWorkspace.shared.runningApplications {
                if app.processIdentifier == parentPID,
                   let bundleId = app.bundleIdentifier,
                   let name = Self.knownApps[bundleId] {
                    return (bundleId, name)
                }
            }
            currentPID = parentPID
        }

        return nil
    }

    // MARK: - Private

    private func activateByPID(_ pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        return app.activate()
    }

    private func activateByBundleId(_ bundleId: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleId
        ).first else {
            return false
        }
        return app.activate()
    }

    private func activateAnyKnownTerminal() -> Bool {
        for bundleId in Self.knownApps.keys {
            if let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId
            ).first, !app.isTerminated {
                return app.activate()
            }
        }
        return false
    }

    private func getParentPID(_ pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size))
        guard result == size else { return 0 }
        return pid_t(info.pbi_ppid)
    }
}
