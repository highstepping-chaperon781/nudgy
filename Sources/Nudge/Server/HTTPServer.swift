import Foundation
import Network

protocol HTTPServerDelegate: AnyObject {
    func httpServer(_ server: HTTPServer, didReceive event: HookEvent)
    func httpServer(_ server: HTTPServer, didEncounterError error: Error)
}

/// Lightweight HTTP server using Network.framework (NWListener).
/// Receives JSON POST requests from AI coding agent hooks on localhost.
final class HTTPServer {
    let requestedPort: UInt16
    private(set) var actualPort: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(
        label: "com.nudgy.httpserver",
        qos: .userInitiated
    )
    weak var delegate: HTTPServerDelegate?

    var sharedSecret: String?

    private static let maxPayloadSize = 65_536 // 64KB
    private static let maxPortAttempts = 3

    enum ServerError: Error, LocalizedError {
        case portUnavailable
        case listenerFailed(Error)

        var errorDescription: String? {
            switch self {
            case .portUnavailable:
                return "All attempted ports are unavailable"
            case .listenerFailed(let error):
                return "Listener failed: \(error.localizedDescription)"
            }
        }
    }

    init(port: UInt16 = 9847) {
        self.requestedPort = port
        self.actualPort = port
    }

    func start() throws {
        for offset in UInt16(0)..<UInt16(Self.maxPortAttempts) {
            let port = requestedPort + offset
            do {
                let params = NWParameters.tcp
                params.requiredLocalEndpoint = NWEndpoint.hostPort(
                    host: .ipv4(.loopback),
                    port: NWEndpoint.Port(rawValue: port)!
                )
                let listener = try NWListener(using: params)

                listener.stateUpdateHandler = { [weak self] state in
                    self?.handleStateUpdate(state)
                }

                listener.newConnectionHandler = { [weak self] connection in
                    self?.handleConnection(connection)
                }

                listener.start(queue: queue)
                self.listener = listener
                self.actualPort = port
                return
            } catch {
                if offset == Self.maxPortAttempts - 1 {
                    throw ServerError.portUnavailable
                }
                continue
            }
        }
        throw ServerError.portUnavailable
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Private

    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .failed(let error):
            delegate?.httpServer(self, didEncounterError: ServerError.listenerFailed(error))
        default:
            break
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveData(on: connection, accumulated: Data())
    }

    private func receiveData(on connection: NWConnection, accumulated: Data) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: Self.maxPayloadSize
        ) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.delegate?.httpServer(self, didEncounterError: error)
                connection.cancel()
                return
            }

            var data = accumulated
            if let content = content {
                data.append(content)
            }

            // Check payload size
            if data.count > Self.maxPayloadSize {
                self.sendResponse(connection, statusCode: 413, body: nil)
                return
            }

            // Check if we have complete HTTP request (headers + body)
            if let request = self.parseHTTPRequest(data) {
                self.processRequest(connection, request: request)
            } else if isComplete {
                // Connection closed before complete request
                self.sendResponse(connection, statusCode: 400, body: nil)
            } else {
                // Need more data
                self.receiveData(on: connection, accumulated: data)
            }
        }
    }

    private struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data?
    }

    private func parseHTTPRequest(_ data: Data) -> HTTPRequest? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }

        // Find header/body separator
        guard let separatorRange = string.range(of: "\r\n\r\n") else { return nil }

        let headerSection = String(string[string.startIndex..<separatorRange.lowerBound])
        let lines = headerSection.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }

        // Parse request line: "POST /event HTTP/1.1"
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Extract body
        let bodyStart = string[separatorRange.upperBound...]
        let bodyData = bodyStart.data(using: .utf8)

        // Check if we have the full body based on Content-Length
        if let contentLengthStr = headers["content-length"],
           let contentLength = Int(contentLengthStr) {
            guard let bodyData = bodyData, bodyData.count >= contentLength else {
                return nil // Need more data
            }
            return HTTPRequest(
                method: method,
                path: path,
                headers: headers,
                body: Data(bodyData.prefix(contentLength))
            )
        }

        return HTTPRequest(
            method: method,
            path: path,
            headers: headers,
            body: bodyData
        )
    }

    private func processRequest(_ connection: NWConnection, request: HTTPRequest) {
        // Only accept POST
        guard request.method == "POST" else {
            sendResponse(connection, statusCode: 405, body: nil)
            return
        }

        // Only accept /event path (strip query string for comparison)
        let pathBase = request.path.components(separatedBy: "?").first ?? request.path
        guard pathBase == "/event" else {
            sendResponse(connection, statusCode: 404, body: nil)
            return
        }

        // Validate auth token if configured
        if let secret = sharedSecret, !secret.isEmpty {
            // Check URL query param (used by Claude Code hooks) or header (API clients)
            let queryToken = Self.extractQueryParam(from: request.path, key: "token")
            let headerToken = request.headers["x-nudgy-token"]
            let providedToken = queryToken ?? headerToken ?? ""
            guard Self.constantTimeEqual(providedToken, secret) else {
                sendResponse(connection, statusCode: 401, body: nil)
                return
            }
        }

        // Parse JSON body
        guard let body = request.body, !body.isEmpty else {
            sendResponse(connection, statusCode: 400, body: nil)
            return
        }

        do {
            let event = try JSONDecoder().decode(HookEvent.self, from: body)
            // Respond immediately before processing
            sendResponse(connection, statusCode: 200, body: "{\"status\":\"ok\"}".data(using: .utf8))
            delegate?.httpServer(self, didReceive: event)
        } catch {
            sendResponse(connection, statusCode: 400, body: nil)
        }
    }

    // MARK: - Auth Helpers

    /// Constant-time string comparison to prevent timing side-channel attacks.
    static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var result: UInt8 = 0
        for i in 0..<aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }
        return result == 0
    }

    /// Extract a query parameter value from a URL path string.
    static func extractQueryParam(from path: String, key: String) -> String? {
        guard let queryStart = path.firstIndex(of: "?") else { return nil }
        let queryString = String(path[path.index(after: queryStart)...])
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 && String(kv[0]) == key {
                return String(kv[1])
            }
        }
        return nil
    }

    private func sendResponse(_ connection: NWConnection, statusCode: Int, body: Data?) {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        case 413: statusText = "Payload Too Large"
        default:  statusText = "Error"
        }

        let bodyData = body ?? Data()
        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "Connection: close\r\n"
        // CORS: reject cross-origin requests from browsers
        response += "Access-Control-Allow-Origin: null\r\n"
        response += "Access-Control-Allow-Methods: POST\r\n"
        response += "\r\n"

        var responseData = response.data(using: .utf8)!
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
