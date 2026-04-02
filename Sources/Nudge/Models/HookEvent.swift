import Foundation

/// Represents an incoming event from an AI coding agent hook.
struct HookEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let hookEventName: String
    let sessionId: String?
    let cwd: String?
    let permissionMode: String?
    let timestamp: Date

    // Notification-specific
    let matcher: String?
    let message: String?
    let title: String?
    let notificationType: String?

    // Tool-use specific
    let toolName: String?
    let toolInput: [String: AnyCodable]?
    let toolUseId: String?

    // Additional fields
    let stopHookActive: Bool?
    let transcriptPath: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case cwd
        case permissionMode = "permission_mode"
        case matcher
        case message
        case title
        case notificationType = "notification_type"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolUseId = "tool_use_id"
        case stopHookActive = "stop_hook_active"
        case transcriptPath = "transcript_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        hookEventName = try container.decode(String.self, forKey: .hookEventName)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        permissionMode = try container.decodeIfPresent(String.self, forKey: .permissionMode)
        matcher = try container.decodeIfPresent(String.self, forKey: .matcher)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        notificationType = try container.decodeIfPresent(String.self, forKey: .notificationType)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolInput = try container.decodeIfPresent([String: AnyCodable].self, forKey: .toolInput)
        toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId)
        stopHookActive = try container.decodeIfPresent(Bool.self, forKey: .stopHookActive)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        timestamp = Date()
    }

    /// Internal initializer for tests and programmatic creation.
    init(
        id: UUID = UUID(),
        hookEventName: String,
        sessionId: String? = nil,
        cwd: String? = nil,
        permissionMode: String? = nil,
        matcher: String? = nil,
        message: String? = nil,
        title: String? = nil,
        notificationType: String? = nil,
        toolName: String? = nil,
        toolInput: [String: AnyCodable]? = nil,
        toolUseId: String? = nil,
        stopHookActive: Bool? = nil,
        transcriptPath: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.hookEventName = hookEventName
        self.sessionId = sessionId
        self.cwd = cwd
        self.permissionMode = permissionMode
        self.matcher = matcher
        self.message = message
        self.title = title
        self.notificationType = notificationType
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolUseId = toolUseId
        self.stopHookActive = stopHookActive
        self.transcriptPath = transcriptPath
        self.timestamp = timestamp
    }
}
