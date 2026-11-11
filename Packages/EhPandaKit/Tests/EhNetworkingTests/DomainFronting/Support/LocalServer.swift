import Foundation
import Network
import Security
import Synchronization

/// A request the local server received in full.
struct LocalRequest: Sendable {
    var method: String
    var target: String
    /// Header names are lowercased.
    var headers: [String: String]
    var body: Data

    /// Takes one complete request off the front of `buffer`, or returns `nil` until one is there.
    init?(consuming buffer: inout Data) {
        guard let headEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let lines = String(decoding: buffer[..<headEnd.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[line[..<colon].lowercased()] = value
        }
        let length = headers["content-length"].flatMap(Int.init) ?? 0
        guard buffer.distance(from: headEnd.upperBound, to: buffer.endIndex) >= length else { return nil }
        let bodyEnd = buffer.index(headEnd.upperBound, offsetBy: length)

        method = String(requestLine[0])
        target = String(requestLine[1])
        self.headers = headers
        body = Data(buffer[headEnd.upperBound..<bodyEnd])
        buffer = Data(buffer[bodyEnd...])
    }
}

/// Opens once. Lets a test hold part of a response back until the client has seen the start.
final class Gate: Sendable {
    private let state = Mutex<(isOpen: Bool, waiting: [@Sendable () -> Void])>((false, []))

    func open() {
        let waiting = state.withLock { state in
            state.isOpen = true
            defer { state.waiting = [] }
            return state.waiting
        }
        waiting.forEach { $0() }
    }

    func whenOpen(_ action: @escaping @Sendable () -> Void) {
        let isOpen = state.withLock { state in
            if !state.isOpen { state.waiting.append(action) }
            return state.isOpen
        }
        if isOpen { action() }
    }
}

/// What the local server sends back for a request.
struct LocalReply: Sendable {
    var status = 200
    var headers: [(name: String, value: String)] = []
    var body = Data()
    /// Sent after `body`, once the gate opens. `Content-Length` covers both parts.
    var held: (data: Data, until: Gate)?
    /// Leaves the request unanswered and the connection open.
    var isSilent = false

    static let silence = LocalReply(isSilent: true)

    static func text(_ text: String, headers: [(name: String, value: String)] = []) -> LocalReply {
        LocalReply(headers: headers, body: Data(text.utf8))
    }

    static func redirect(_ status: Int = 302, to location: String) -> LocalReply {
        LocalReply(status: status, headers: [("Location", location)])
    }
}

/// An HTTP/1.1 server on loopback that records everything it receives.
///
/// With an identity it speaks TLS, and what it records are the bytes that arrived *inside* the
/// TLS session: nothing is recorded for a client that gave up during the handshake. Without one
/// it records the raw bytes of the connection (the client's TLS handshake) and never answers.
final class LocalServer: Sendable {
    struct Record: Sendable {
        /// Connections accepted, whether or not a handshake followed.
        var connections = 0
        /// Connections on which the TLS handshake completed.
        var handshakes = 0
        /// Connections that have ended.
        var closed = 0
        var received = Data()
        var requests: [LocalRequest] = []
    }

    let port: Int
    private let listener: NWListener
    private let connections: Connections

    init(
        identity: SecIdentity? = TestCertificates.makeIdentity(),
        reply: @escaping @Sendable (LocalRequest) -> LocalReply = { _ in .text("ok") }
    ) async throws {
        let parameters: NWParameters
        if let identity, let secIdentity = sec_identity_create(identity) {
            let tls = NWProtocolTLS.Options()
            sec_protocol_options_set_local_identity(tls.securityProtocolOptions, secIdentity)
            parameters = NWParameters(tls: tls)
        } else {
            parameters = .tcp
        }
        // Loopback only: nothing off this machine can reach it, and macOS does not ask about it.
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters)
        let connections = Connections(reply: reply)
        self.listener = listener
        self.connections = connections

        let (states, continuation) = AsyncStream.makeStream(of: NWListener.State.self)
        listener.stateUpdateHandler = { continuation.yield($0) }
        listener.newConnectionHandler = { connections.accept($0) }
        listener.start(queue: connections.queue)
        var port: Int?
        for await state in states {
            if case .ready = state { port = listener.port.map { Int($0.rawValue) } }
            if case .failed(let error) = state { throw error }
            if port != nil { break }
        }
        guard let port else { throw URLError(.cannotConnectToHost) }
        self.port = port
        listener.stateUpdateHandler = nil
    }

    deinit { stop() }

    var record: Record { connections.record }

    /// What arrived, as text.
    var receivedText: String { String(decoding: record.received, as: UTF8.self) }

    func stop() {
        listener.cancel()
        connections.cancelAll()
    }

    /// Stops, and returns once the port no longer accepts connections.
    func stopListening() async {
        let (states, continuation) = AsyncStream.makeStream(of: NWListener.State.self)
        listener.stateUpdateHandler = { continuation.yield($0) }
        stop()
        for await state in states {
            if case .cancelled = state { break }
        }
    }
}

/// The server's connections and what arrived on them.
private final class Connections: Sendable {
    let queue = DispatchQueue(label: "LocalServer")
    private let state = Mutex((record: LocalServer.Record(), open: [NWConnection]()))
    private let reply: @Sendable (LocalRequest) -> LocalReply

    init(reply: @escaping @Sendable (LocalRequest) -> LocalReply) {
        self.reply = reply
    }

    var record: LocalServer.Record { state.withLock { $0.record } }

    func cancelAll() {
        state.withLock { $0.open }.forEach { $0.cancel() }
    }

    func accept(_ connection: NWConnection) {
        state.withLock {
            $0.record.connections += 1
            $0.open.append(connection)
        }
        connection.stateUpdateHandler = { [self, weak connection] newState in
            switch newState {
            case .ready: state.withLock { $0.record.handshakes += 1 }
            case .failed: connection?.cancel()
            case .cancelled: state.withLock { $0.record.closed += 1 }
            default: break
            }
        }
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [self] data, _, isComplete, error in
            var buffer = buffer
            if let data, !data.isEmpty {
                state.withLock { $0.record.received.append(data) }
                buffer.append(data)
                while let request = LocalRequest(consuming: &buffer) {
                    state.withLock { $0.record.requests.append(request) }
                    send(reply(request), on: connection)
                }
            }
            if isComplete || error != nil {
                connection.cancel()
            } else {
                receive(on: connection, buffer: buffer)
            }
        }
    }

    private func send(_ reply: LocalReply, on connection: NWConnection) {
        guard !reply.isSilent else { return }
        var head = "HTTP/1.1 \(reply.status) Status\r\n"
        head += "Content-Length: \(reply.body.count + (reply.held?.data.count ?? 0))\r\n"
        for header in reply.headers {
            head += "\(header.name): \(header.value)\r\n"
        }
        head += "\r\n"
        connection.send(content: Data(head.utf8) + reply.body, completion: .contentProcessed { _ in })
        if let held = reply.held {
            held.until.whenOpen {
                connection.send(content: held.data, completion: .contentProcessed { _ in })
            }
        }
    }
}

/// The parts of a TLS ClientHello that show what a network observer learns from it.
struct ClientHello {
    /// The `server_name` extension, absent when the client did not name the server.
    var serverName: String?
    /// The application protocols offered (ALPN).
    var protocols: [String] = []

    /// Parses the first TLS record of a connection, or returns `nil` when it is not a ClientHello.
    init?(record: Data) {
        let bytes = [UInt8](record)
        // Record header (5), handshake header (4), version (2) and random (32) precede the session id.
        guard bytes.count > 43, bytes[0] == 0x16, bytes[5] == 0x01 else { return nil }
        // Wait for the whole record, so that no extension can be missed.
        guard bytes.count >= 5 + (Int(bytes[3]) << 8 | Int(bytes[4])) else { return nil }
        var index = 43
        func length(_ size: Int) -> Int? {
            guard index + size <= bytes.count else { return nil }
            defer { index += size }
            return bytes[index..<index + size].reduce(0) { $0 << 8 | Int($1) }
        }
        guard let sessionID = length(1) else { return nil }
        index += sessionID
        guard let cipherSuites = length(2) else { return nil }
        index += cipherSuites
        guard let compression = length(1) else { return nil }
        index += compression
        guard let extensionsLength = length(2), index + extensionsLength <= bytes.count else { return nil }
        let end = index + extensionsLength

        while index + 4 <= end {
            guard let type = length(2), let size = length(2), index + size <= end else { return nil }
            let body = Array(bytes[index..<index + size])
            index += size
            switch type {
            case 0 where body.count > 5:
                // List length (2), name type (1), name length (2), then the name.
                serverName = String(decoding: body[5...], as: UTF8.self)
            case 16:
                var offset = 2
                while offset < body.count {
                    let nameEnd = min(offset + 1 + Int(body[offset]), body.count)
                    protocols.append(String(decoding: body[(offset + 1)..<nameEnd], as: UTF8.self))
                    offset = nameEnd
                }
            default:
                break
            }
        }
    }
}

/// Waits until `condition` holds, for up to `timeout`. Loose on purpose: these tests do real
/// socket I/O and must not fail on a busy machine.
func eventually(timeout: Duration = .seconds(20), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now >= deadline { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}
