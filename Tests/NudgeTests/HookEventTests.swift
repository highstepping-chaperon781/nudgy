import XCTest
@testable import Nudgy

final class HookEventTests: XCTestCase {

    func testDecodeStopEvent() throws {
        let json = """
        {
            "hook_event_name": "Stop",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "permission_mode": "default",
            "stop_hook_active": false
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Stop")
        XCTAssertEqual(event.sessionId, "abc-123-def")
        XCTAssertEqual(event.cwd, "/Users/dev/myproject")
        XCTAssertEqual(event.permissionMode, "default")
        XCTAssertEqual(event.stopHookActive, false)
        XCTAssertNil(event.matcher)
    }

    func testDecodeNotificationPermissionPrompt() throws {
        let json = """
        {
            "hook_event_name": "Notification",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "matcher": "permission_prompt"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Notification")
        XCTAssertEqual(event.matcher, "permission_prompt")
    }

    func testDecodeNotificationIdlePrompt() throws {
        let json = """
        {
            "hook_event_name": "Notification",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "matcher": "idle_prompt"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Notification")
        XCTAssertEqual(event.matcher, "idle_prompt")
    }

    func testDecodeStopFailure() throws {
        let json = """
        {
            "hook_event_name": "StopFailure",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "matcher": "rate_limit"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "StopFailure")
        XCTAssertEqual(event.matcher, "rate_limit")
    }

    func testDecodeSessionStart() throws {
        let json = """
        {
            "hook_event_name": "SessionStart",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "matcher": "startup"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "SessionStart")
        XCTAssertEqual(event.matcher, "startup")
    }

    func testDecodeSessionEnd() throws {
        let json = """
        {
            "hook_event_name": "SessionEnd",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "matcher": "prompt_input_exit"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "SessionEnd")
        XCTAssertEqual(event.matcher, "prompt_input_exit")
    }

    func testDecodeWithMissingOptionalFields() throws {
        let json = """
        {
            "hook_event_name": "Stop"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Stop")
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.cwd)
        XCTAssertNil(event.matcher)
        XCTAssertNil(event.toolName)
        XCTAssertNil(event.toolInput)
    }

    func testDecodeWithUnknownEventName() throws {
        let json = """
        {
            "hook_event_name": "FutureEvent",
            "session_id": "abc-123-def"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "FutureEvent")
    }

    func testDecodeInvalidJSON() {
        let json = "not json at all".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(HookEvent.self, from: json))
    }

    func testDecodeWithToolInput() throws {
        let json = """
        {
            "hook_event_name": "Notification",
            "session_id": "abc-123",
            "matcher": "permission_prompt",
            "tool_name": "Bash",
            "tool_input": {
                "command": "ls -la",
                "description": "List files"
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertNotNil(event.toolInput)
        XCTAssertEqual(event.toolInput?["command"]?.value as? String, "ls -la")
    }

    func testEventHasUniqueId() throws {
        let json = """
        {"hook_event_name": "Stop"}
        """.data(using: .utf8)!

        let event1 = try JSONDecoder().decode(HookEvent.self, from: json)
        let event2 = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertNotEqual(event1.id, event2.id)
    }
}
