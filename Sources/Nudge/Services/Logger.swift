import Foundation

/// Simple file logger for troubleshooting. Writes to ~/Library/Logs/Nudge/nudge.log.
final class NudgeLogger {
    static let shared = NudgeLogger()

    private let fileHandle: FileHandle?
    private let logDir: URL
    private let logFile: URL
    private let queue = DispatchQueue(label: "com.nudge.logger")
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private init() {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        logDir = library.appendingPathComponent("Logs/Nudge")
        logFile = logDir.appendingPathComponent("nudge.log")

        // Create directory
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        // Rotate if > 5MB
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
           let size = attrs[.size] as? UInt64, size > 5_000_000 {
            let oldLog = logDir.appendingPathComponent("nudge.old.log")
            try? FileManager.default.removeItem(at: oldLog)
            try? FileManager.default.moveItem(at: logFile, to: oldLog)
        }

        // Create file if needed
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }

        fileHandle = FileHandle(forWritingAtPath: logFile.path)
        fileHandle?.seekToEndOfFile()

        log("--- Nudge started ---")
    }

    func log(_ message: String, level: String = "INFO") {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)\n"

        // Write to file
        queue.async { [weak self] in
            if let data = line.data(using: .utf8) {
                self?.fileHandle?.write(data)
            }
        }

        // Also write to NSLog for Console.app
        NSLog("Nudge: %@", message)
    }

    func event(_ eventName: String, sessionId: String?, matcher: String?, tool: String?, cwd: String?) {
        log("EVENT \(eventName) | session=\(sessionId ?? "-") | matcher=\(matcher ?? "-") | tool=\(tool ?? "-") | cwd=\(cwd ?? "-")")
    }

    func error(_ message: String) {
        log(message, level: "ERROR")
    }

    var logFilePath: String { logFile.path }

    deinit {
        fileHandle?.closeFile()
    }
}
