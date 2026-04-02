import XCTest
@testable import Nudgy

final class HTTPServerTests: XCTestCase {
    private var server: HTTPServer!
    private var eventDelegate: MockHTTPServerDelegate!

    override func setUp() {
        super.setUp()
        eventDelegate = MockHTTPServerDelegate()
        server = HTTPServer(port: 19847) // Use high port for tests
        server.delegate = eventDelegate
    }

    override func tearDown() {
        server.stop()
        server = nil
        eventDelegate = nil
        super.tearDown()
    }

    func testServerStartsAndListens() throws {
        try server.start()
        // Give listener time to start
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(server.actualPort, 19847)
    }

    func testServerReceivesValidJSON() async throws {
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await sendTestEvent(
            port: server.actualPort,
            json: ["hook_event_name": "Stop", "session_id": "test-1"]
        )

        XCTAssertEqual(result.statusCode, 200)

        // Wait for delegate callback
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(eventDelegate.receivedEvents.count, 1)
        XCTAssertEqual(eventDelegate.receivedEvents.first?.hookEventName, "Stop")
    }

    func testServerRejectsNonPOST() async throws {
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await sendRawRequest(
            port: server.actualPort,
            method: "GET",
            path: "/event",
            body: nil
        )

        XCTAssertEqual(result.statusCode, 405)
    }

    func testServerRejectsInvalidJSON() async throws {
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await sendRawRequest(
            port: server.actualPort,
            method: "POST",
            path: "/event",
            body: "not json at all"
        )

        XCTAssertEqual(result.statusCode, 400)
    }

    func testServerRejectsInvalidToken() async throws {
        server.sharedSecret = "correct-token"
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await sendTestEvent(
            port: server.actualPort,
            json: ["hook_event_name": "Stop"],
            token: "wrong-token"
        )

        XCTAssertEqual(result.statusCode, 401)
    }

    func testServerAcceptsValidToken() async throws {
        server.sharedSecret = "correct-token"
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await sendTestEvent(
            port: server.actualPort,
            json: ["hook_event_name": "Stop", "session_id": "s1"],
            token: "correct-token"
        )

        XCTAssertEqual(result.statusCode, 200)
    }

    func testServerHandlesConcurrentConnections() async throws {
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let result = try await self.sendTestEvent(
                        port: self.server.actualPort,
                        json: ["hook_event_name": "Stop", "session_id": "s-\(i)"]
                    )
                    XCTAssertEqual(result.statusCode, 200)
                }
            }
            try await group.waitForAll()
        }

        // Wait for all delegate callbacks
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(eventDelegate.receivedEvents.count, 10)
    }

    func testServerStopsGracefully() throws {
        try server.start()
        Thread.sleep(forTimeInterval: 0.1)
        server.stop()
        Thread.sleep(forTimeInterval: 0.1)

        // Should be able to start a new server on the same port
        let server2 = HTTPServer(port: server.actualPort)
        XCTAssertNoThrow(try server2.start())
        server2.stop()
    }

    func testServerResponds200() async throws {
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await sendTestEvent(
            port: server.actualPort,
            json: ["hook_event_name": "Stop", "session_id": "s1"]
        )

        XCTAssertEqual(result.statusCode, 200)
        let body = String(data: result.body, encoding: .utf8)
        XCTAssertEqual(body, "{\"status\":\"ok\"}")
    }

    func testServerRejectsWrongPath() async throws {
        try server.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await sendRawRequest(
            port: server.actualPort,
            method: "POST",
            path: "/wrong",
            body: "{\"hook_event_name\":\"Stop\"}"
        )

        XCTAssertEqual(result.statusCode, 404)
    }

    // MARK: - Helpers

    private func sendTestEvent(
        port: UInt16,
        json: [String: Any],
        token: String? = nil
    ) async throws -> (statusCode: Int, body: Data) {
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let body = String(data: jsonData, encoding: .utf8)!

        return try await sendRawRequest(
            port: port,
            method: "POST",
            path: "/event",
            body: body,
            token: token
        )
    }

    private func sendRawRequest(
        port: UInt16,
        method: String,
        path: String,
        body: String?,
        token: String? = nil
    ) async throws -> (statusCode: Int, body: Data) {
        var url = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        url.httpMethod = method
        url.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            url.setValue(token, forHTTPHeaderField: "X-Nudgy-Token")
        }
        if let body = body {
            url.httpBody = body.data(using: .utf8)
        }

        let (data, response) = try await URLSession.shared.data(for: url)
        let httpResponse = response as! HTTPURLResponse
        return (httpResponse.statusCode, data)
    }
}

// MARK: - Mock Delegate

final class MockHTTPServerDelegate: HTTPServerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _receivedEvents: [HookEvent] = []
    private var _errors: [Error] = []

    var receivedEvents: [HookEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _receivedEvents
    }

    var errors: [Error] {
        lock.lock()
        defer { lock.unlock() }
        return _errors
    }

    func httpServer(_ server: HTTPServer, didReceive event: HookEvent) {
        lock.lock()
        _receivedEvents.append(event)
        lock.unlock()
    }

    func httpServer(_ server: HTTPServer, didEncounterError error: Error) {
        lock.lock()
        _errors.append(error)
        lock.unlock()
    }
}
