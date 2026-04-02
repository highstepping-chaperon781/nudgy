# Agent 02: HTTP Server

## Objective
Implement a lightweight HTTP server using Apple's Network.framework (NWListener)
that receives JSON POST requests from AI coding agent hooks on localhost.

## Scope
- TCP listener on configurable port (default 9847)
- Minimal HTTP/1.1 request parser (POST only)
- JSON deserialization into HookEvent
- Token validation (shared secret)
- Response sending (200 OK / 401 Unauthorized)
- Concurrent connection handling
- Graceful start/stop

## Dependencies
- Agent 01: Project structure exists
- Agent 03: `HookEvent` model (can use a temporary stub if Agent 03 isn't done)

## Files to Create

### Sources/Nudge/Server/HTTPServer.swift

```swift
import Foundation
import Network

protocol HTTPServerDelegate: AnyObject {
    func httpServer(_ server: HTTPServer, didReceive event: HookEvent)
    func httpServer(_ server: HTTPServer, didEncounterError error: Error)
}

final class HTTPServer {
    let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(
        label: "com.nudge.httpserver",
        qos: .userInitiated
    )
    weak var delegate: HTTPServerDelegate?

    init(port: UInt16 = 9847) {
        self.port = port
    }

    func start() throws { ... }
    func stop() { ... }

    // MARK: - Private

    private func handleConnection(_ connection: NWConnection) { ... }
    private func parseHTTPRequest(_ data: Data) -> (headers: [String: String], body: Data?)? { ... }
    private func sendResponse(_ connection: NWConnection, statusCode: Int, body: Data?) { ... }
}
```

### Key Implementation Details

1. **HTTP Parser**: Parse only what we need:
   - Extract method (reject non-POST with 405)
   - Extract Content-Length header
   - Extract X-Nudge-Token header
   - Read body bytes based on Content-Length
   - Split on `\r\n\r\n` to separate headers from body

2. **Connection handling**:
   - `listener.newConnectionHandler` receives each connection
   - Call `connection.receive(minimumIncompleteLength:maximumLength:)`
   - Process in a single read (events are small, < 10KB)
   - Send response and close connection

3. **Token validation**:
   - Compare request token against stored shared secret
   - Reject with 401 if mismatch
   - Skip validation if no token is configured (first-run state)

4. **Error handling**:
   - Port already in use → try port+1, port+2; report via delegate
   - Connection errors → log and continue (don't crash)
   - Malformed JSON → log, respond 400, continue
   - Oversized request (> 64KB) → reject with 413

## Tests to Write

### Tests/NudgeTests/HTTPServerTests.swift

```swift
import XCTest
@testable import Nudge

final class HTTPServerTests: XCTestCase {

    func testServerStartsAndListens() async throws {
        // Start server, verify listener state is .ready
    }

    func testServerReceivesValidJSON() async throws {
        // POST valid HookEvent JSON, verify delegate receives it
    }

    func testServerRejectsNonPOST() async throws {
        // GET request → 405
    }

    func testServerRejectsInvalidJSON() async throws {
        // POST garbage → 400
    }

    func testServerRejectsInvalidToken() async throws {
        // POST with wrong token → 401
    }

    func testServerHandlesConcurrentConnections() async throws {
        // Send 10 POSTs concurrently, verify all 10 received
    }

    func testServerRejectsOversizedPayload() async throws {
        // POST > 64KB → 413
    }

    func testServerStopsGracefully() async throws {
        // Start, stop, verify port is released
    }

    func testServerPortFallback() async throws {
        // Bind port 9847 externally, start server → uses 9848
    }

    func testServerResponds200() async throws {
        // POST valid event, verify HTTP 200 response
    }
}
```

### Test Helper

Create a test helper that sends HTTP requests to the server:

```swift
func sendTestEvent(
    port: UInt16,
    json: [String: Any],
    token: String? = nil
) async throws -> (statusCode: Int, body: Data) {
    // Use URLSession to POST to localhost
}
```

## Self-Verification

1. `swift build` compiles with no errors
2. All 10 tests pass
3. Server handles 100 rapid sequential requests without crashing
4. Server releases port on stop (verified by re-binding)
5. Memory: no leaks detected (check with Instruments if possible)

## Performance Requirements
- Event processing latency: < 10ms from TCP receive to delegate callback
- Max concurrent connections: 20
- Memory overhead: < 5MB for server component
