import Foundation

/// Token usage data extracted from a Claude Code transcript.
struct TokenUsage: Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var model: String = ""

    /// Total tokens: input + output only.
    /// Note: input_tokens from the API already includes cache tokens,
    /// so cache fields are NOT added again here.
    var totalTokens: Int {
        inputTokens + outputTokens
    }

    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000)
        }
        if totalTokens >= 1_000 {
            return String(format: "%.1fk", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }
}

/// Parses Claude Code transcript JSONL files to extract token usage data.
final class TranscriptParser {

    /// Find the transcript JSONL file for a given session.
    static func findTranscript(sessionId: String, cwd: String?) -> URL? {
        guard let cwd = cwd else { return nil }

        // Reject path traversal in session ID and cwd
        guard !sessionId.contains("..") && !sessionId.contains("/") && !sessionId.contains("\\") else {
            return nil
        }
        guard !cwd.contains("..") else {
            return nil
        }

        // Convert cwd to Claude's project slug: replace "/" with "-"
        // e.g. /Users/hammad/Projects/nudge -> -Users-hammad-Projects-nudge
        let slug = cwd.replacingOccurrences(of: "/", with: "-")

        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")

        let transcriptPath = projectsDir
            .appendingPathComponent(slug)
            .appendingPathComponent("\(sessionId).jsonl")

        // Verify resolved path stays within the projects directory
        let resolvedPath = transcriptPath.standardizedFileURL.path
        let allowedPrefix = projectsDir.standardizedFileURL.path
        guard resolvedPath.hasPrefix(allowedPrefix) else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: transcriptPath.path) else {
            return nil
        }

        return transcriptPath
    }

    /// Parse a transcript file and return cumulative token usage.
    /// Reads the file line-by-line to avoid loading large files entirely into memory.
    static func parseUsage(sessionId: String, cwd: String?) -> TokenUsage? {
        guard let url = findTranscript(sessionId: sessionId, cwd: cwd) else {
            return nil
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? fileHandle.close() }

        var usage = TokenUsage()
        var foundAny = false
        let bufferSize = 64 * 1024 // 64KB chunks
        var leftover = Data()

        while true {
            let chunk = fileHandle.readData(ofLength: bufferSize)
            if chunk.isEmpty && leftover.isEmpty {
                break
            }

            let data: Data
            if leftover.isEmpty {
                data = chunk
            } else {
                data = leftover + chunk
                leftover = Data()
            }

            // Split by newlines
            guard let text = String(data: data, encoding: .utf8) else {
                break
            }

            var lines = text.split(separator: "\n", omittingEmptySubsequences: false)

            // If chunk is not empty, the last "line" may be incomplete — save it as leftover
            if !chunk.isEmpty {
                if let lastPart = lines.last {
                    leftover = Data(String(lastPart).utf8)
                    lines.removeLast()
                }
            }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                // Quick check before parsing JSON
                guard trimmed.contains("\"type\"") && trimmed.contains("\"assistant\"") else {
                    continue
                }

                guard let lineData = trimmed.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                    continue
                }

                guard let type = json["type"] as? String, type == "assistant" else {
                    continue
                }

                guard let message = json["message"] as? [String: Any] else {
                    continue
                }

                // Extract model (skip synthetic models)
                if let model = message["model"] as? String,
                   !model.contains("<synthetic>") && !model.isEmpty {
                    usage.model = model
                }

                // Extract usage
                if let usageDict = message["usage"] as? [String: Any] {
                    foundAny = true
                    if let v = usageDict["input_tokens"] as? Int {
                        usage.inputTokens += v
                    }
                    if let v = usageDict["output_tokens"] as? Int {
                        usage.outputTokens += v
                    }
                    if let v = usageDict["cache_creation_input_tokens"] as? Int {
                        usage.cacheCreationTokens += v
                    }
                    if let v = usageDict["cache_read_input_tokens"] as? Int {
                        usage.cacheReadTokens += v
                    }
                }
            }
        }

        return foundAny ? usage : nil
    }
}
