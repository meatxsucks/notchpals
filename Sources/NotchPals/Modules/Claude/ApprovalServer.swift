import Foundation
import Network

/// Servidor local (solo loopback) que recibe las peticiones del hook de Claude Code
/// y las deja pendientes hasta que el usuario decide desde el notch.
@MainActor
final class ApprovalServer: ObservableObject {
    static let shared = ApprovalServer()
    static let port: UInt16 = 47600
    static let timeoutSeconds: UInt64 = 100 // el hook de Claude Code permite 120 s

    struct Pending: Identifiable {
        let request: ApprovalRequest
        let respond: (ApprovalDecision) -> Void
        var id: UUID { request.id }
    }

    @Published private(set) var pending: [Pending] = []
    @Published private(set) var isRunning = false

    private var listener: NWListener?
    private let token = ApprovalServer.loadOrCreateToken()

    func start() {
        guard listener == nil else { return }
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        guard let port = NWEndpoint.Port(rawValue: Self.port),
              let listener = try? NWListener(using: parameters, on: port) else { return }
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            Task { @MainActor in self?.receive(connection, buffer: Data()) }
        }
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .ready = state { self?.isRunning = true }
                if case .failed = state { self?.isRunning = false; self?.listener = nil }
            }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    func resolve(_ id: UUID, decision: ApprovalDecision) {
        guard let item = pending.first(where: { $0.id == id }) else { return }
        item.respond(decision)
    }

    // MARK: - Red

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { connection.cancel(); return }
                var buffer = buffer
                if let data { buffer.append(data) }
                if let request = HTTPRequestParser.parse(buffer) {
                    self.handle(request, on: connection)
                } else if error != nil || isComplete || buffer.count > 1_000_000 {
                    connection.cancel()
                } else {
                    self.receive(connection, buffer: buffer)
                }
            }
        }
    }

    private func handle(_ http: HTTPRequestParser.Request, on connection: NWConnection) {
        guard http.method == "POST", http.headers["x-notchpals-token"] == token else {
            send(connection, status: 403, body: Data("{}".utf8))
            return
        }
        if http.path == "/event" { // eventos que no bloquean a Claude Code
            if let event = SessionEvent.parse(http.body) { SessionTracker.shared.apply(event) }
            send(connection, status: 204, body: Data())
            return
        }
        guard http.path == "/approve", let request = ApprovalProtocol.parse(http.body) else {
            send(connection, status: 400, body: Data("{}".utf8))
            return
        }
        var answered = false
        let id = request.id
        let respond: (ApprovalDecision) -> Void = { [weak self] decision in
            guard !answered else { return }
            answered = true
            self?.pending.removeAll { $0.id == id }
            if let body = ApprovalProtocol.responseJSON(decision, request: request) {
                self?.send(connection, status: 200, body: body)
            } else {
                self?.send(connection, status: 204, body: Data()) // sin salida → diálogo normal
            }
        }
        pending.append(Pending(request: request, respond: respond))
        // Sin respuesta a tiempo: se devuelve "ask" y Claude Code pregunta en la terminal.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.timeoutSeconds * 1_000_000_000)
            respond(.ask)
        }
    }

    private func send(_ connection: NWConnection, status: Int, body: Data) {
        let head = "HTTP/1.1 \(status) \(status == 200 ? "OK" : (status == 204 ? "No Content" : "Error"))\r\n"
            + "Content-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Token compartido con el script del hook (~/.notchpals/token)

    private static func loadOrCreateToken() -> String {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".notchpals")
        let file = directory.appendingPathComponent("token")
        if let existing = try? String(contentsOf: file, encoding: .utf8), !existing.isEmpty {
            return existing.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let token = UUID().uuidString + UUID().uuidString
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        try? token.write(to: file, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return token
    }
}
