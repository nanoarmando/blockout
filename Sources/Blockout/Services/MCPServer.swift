import Foundation
import Network
import Observation

/// Loopback-only MCP endpoint: HTTP/1.1 `POST /mcp` carrying one JSON-RPC message, answered with JSON (no SSE,
/// no sessions). Every connection serves a single request and is closed.
@MainActor
@Observable
final class MCPServer {
    nonisolated static let defaultPort = 43219
    private static let maxRequestSize = 1_048_576
    private static let protocolVersion = "2025-06-18"

    enum Status: Equatable {
        case off, starting, active, portBusy
        case failed(String)
    }

    private(set) var status = Status.off
    private(set) var port = defaultPort
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var appliedConfiguration: (enabled: Bool, port: Int)?
    @ObservationIgnored private let tools: MCPTools

    var address: String { "http://127.0.0.1:\(port)/mcp" }

    init(tools: MCPTools) {
        self.tools = tools
    }

    /// Starts, stops or rebinds the listener for the given settings. A busy or failed port is retried on every call.
    func configure(enabled: Bool, port: Int) {
        let isRetry = status == .portBusy || { if case .failed = status { true } else { false } }()
        if let applied = appliedConfiguration, applied.enabled == enabled, applied.port == port, !isRetry { return }
        appliedConfiguration = (enabled, port)
        listener?.cancel()
        listener = nil
        self.port = port
        status = .off
        if enabled { start() }
    }

    private func start() {
        guard (1...65_535).contains(port), let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            status = .failed("Puerto no válido")
            return
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: endpointPort)
        parameters.acceptLocalOnly = true
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            status = .failed(error.localizedDescription)
            return
        }
        listener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.listenerChanged(state, listener: listener) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        self.listener = listener
        status = .starting
        listener.start(queue: .main)
    }

    private func listenerChanged(_ state: NWListener.State, listener: NWListener) {
        guard listener === self.listener else { return }
        switch state {
        case .ready:
            status = .active
        case .failed(let error), .waiting(let error):
            if case .posix(.EADDRINUSE) = error { status = .portBusy } else { status = .failed(error.localizedDescription) }
            listener.cancel()
            self.listener = nil
        default:
            break
        }
    }

    // MARK: HTTP

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else { return connection.cancel() }
                var buffer = buffer
                if let data { buffer.append(data) }
                switch HTTPRequest.parse(buffer) {
                case .complete(let request):
                    self.send(self.response(to: request), on: connection)
                case .incomplete where error == nil && !isComplete && buffer.count <= Self.maxRequestSize:
                    self.receive(on: connection, buffer: buffer)
                case .incomplete, .invalid:
                    self.send(HTTPResponse(status: "400 Bad Request"), on: connection)
                }
            }
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.serialized, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func response(to request: HTTPRequest) -> HTTPResponse {
        guard request.path == "/mcp" else { return HTTPResponse(status: "404 Not Found") }
        // Browsers send Origin; rejecting foreign origins blocks DNS-rebinding pages from reaching the loopback port.
        if let origin = request.headers["origin"], !Self.isLocalOrigin(origin) {
            return HTTPResponse(status: "403 Forbidden")
        }
        guard request.method == "POST" else { return HTTPResponse(status: "405 Method Not Allowed", extraHeaders: ["Allow": "POST"]) }
        guard let message = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] else {
            return .json(Self.rpcError(id: NSNull(), code: -32700, message: "Parse error: expected one JSON-RPC object"))
        }
        guard let reply = reply(to: message) else { return HTTPResponse(status: "202 Accepted") }
        return .json(reply)
    }

    private static func isLocalOrigin(_ origin: String) -> Bool {
        guard let host = URL(string: origin)?.host() else { return false }
        return ["127.0.0.1", "localhost", "::1"].contains(host)
    }

    // MARK: JSON-RPC

    /// The JSON-RPC response, or `nil` for a notification.
    private func reply(to message: [String: Any]) -> [String: Any]? {
        guard let method = message["method"] as? String else {
            return Self.rpcError(id: message["id"] ?? NSNull(), code: -32600, message: "Invalid request: missing method")
        }
        guard let id = message["id"] else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]
        let result: [String: Any]
        switch method {
        case "initialize":
            result = [
                "protocolVersion": params["protocolVersion"] as? String ?? Self.protocolVersion,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "blockout", "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"],
                "instructions": "Blockout plans tasks as time blocks in the user's calendar. Times use the user's local time zone; send ISO 8601 (e.g. 2026-10-15T16:00 or with offset). Use propose_blocks to suggest a plan the user reviews; schedule_task writes to the calendar immediately.",
            ]
        case "ping":
            result = [:]
        case "tools/list":
            result = ["tools": MCPTools.definitions]
        case "tools/call":
            guard let name = params["name"] as? String else {
                return Self.rpcError(id: id, code: -32602, message: "Invalid params: missing tool name")
            }
            result = tools.call(name, arguments: params["arguments"] as? [String: Any] ?? [:])
        default:
            return Self.rpcError(id: id, code: -32601, message: "Method not found: \(method)")
        }
        return ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private static func rpcError(id: Any, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }
}

private struct HTTPRequest {
    enum ParseResult {
        case complete(HTTPRequest)
        case incomplete
        case invalid
    }

    let method: String
    let path: String
    /// Lowercased names.
    let headers: [String: String]
    let body: Data

    static func parse(_ buffer: Data) -> ParseResult {
        guard let headerEnd = buffer.firstRange(of: Data("\r\n\r\n".utf8)) else { return .incomplete }
        guard let head = String(data: buffer[buffer.startIndex..<headerEnd.lowerBound], encoding: .utf8) else { return .invalid }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count == 3 else { return .invalid }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return .invalid }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = headers["content-length"].flatMap { Int($0) } ?? 0
        let body = buffer[headerEnd.upperBound...]
        guard body.count >= length else { return .incomplete }
        let path = requestLine[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
        return .complete(HTTPRequest(method: String(requestLine[0]), path: path, headers: headers, body: Data(body.prefix(length))))
    }
}

private struct HTTPResponse {
    let status: String
    var extraHeaders: [String: String] = [:]
    var body = Data()
    var contentType: String?

    static func json(_ object: [String: Any]) -> HTTPResponse {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])) ?? Data()
        return HTTPResponse(status: "200 OK", body: body, contentType: "application/json")
    }

    var serialized: Data {
        var head = "HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
        if let contentType { head += "Content-Type: \(contentType)\r\n" }
        for (name, value) in extraHeaders { head += "\(name): \(value)\r\n" }
        return Data((head + "\r\n").utf8) + body
    }
}
