import Foundation

/// Evento de hook de Claude Code (los que no bloquean).
struct SessionEvent {
    let sessionID: String
    let cwd: String
    let name: String
    let tool: String?
    let input: [String: Any]

    static func parse(_ data: Data) -> SessionEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["session_id"] as? String,
              let name = json["hook_event_name"] as? String else { return nil }
        return SessionEvent(sessionID: id, cwd: json["cwd"] as? String ?? "", name: name,
                            tool: json["tool_name"] as? String, input: json["tool_input"] as? [String: Any] ?? [:])
    }
}

struct FileChange: Equatable {
    var added = 0
    var removed = 0
}

struct SessionInfo: Identifiable, Equatable {
    enum State { case working, idle }
    let id: String
    var project: String
    var state: State
    var action: String
    var changes: [String: FileChange] = [:]
    var lastActivity: Date

    var totalAdded: Int { changes.values.reduce(0) { $0 + $1.added } }
    var totalRemoved: Int { changes.values.reduce(0) { $0 + $1.removed } }
}

enum SessionReducer {
    static let maxAge: TimeInterval = 60 * 60

    static func apply(_ event: SessionEvent, to sessions: inout [String: SessionInfo], now: Date = Date()) {
        if event.name == "SessionEnd" { sessions[event.sessionID] = nil; return }
        var info = sessions[event.sessionID] ?? SessionInfo(
            id: event.sessionID, project: projectName(event.cwd), state: .idle, action: "Sesión iniciada", lastActivity: now)
        info.lastActivity = now
        switch event.name {
        case "PreToolUse":
            info.state = .working
            info.action = describe(tool: event.tool ?? "", input: event.input)
        case "PostToolUse":
            info.state = .working
            if let tool = event.tool, let (path, change) = fileChange(tool: tool, input: event.input) {
                var total = info.changes[path] ?? FileChange()
                total.added += change.added
                total.removed += change.removed
                info.changes[path] = total
            }
        case "Stop":
            info.state = .idle
            info.action = "Terminado"
        default:
            break
        }
        sessions[event.sessionID] = info
        sessions = sessions.filter { now.timeIntervalSince($0.value.lastActivity) < maxAge }
    }

    static func projectName(_ cwd: String) -> String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? "Sesión" : name
    }

    static func describe(tool: String, input: [String: Any]) -> String {
        let file = (input["file_path"] as? String).map { ($0 as NSString).lastPathComponent } ?? ""
        switch tool {
        case "Read": return "Leyendo \(file)"
        case "Edit", "MultiEdit", "Write", "NotebookEdit": return "Editando \(file)"
        case "Bash":
            let command = (input["command"] as? String ?? "").replacingOccurrences(of: "\n", with: " ")
            return "Ejecutando: " + String(command.prefix(60))
        case "Grep", "Glob": return "Buscando en el proyecto"
        case "WebFetch", "WebSearch": return "Consultando la web"
        case "Task", "Agent": return "Delegando a un subagente"
        default: return tool
        }
    }

    /// Cambios aproximados (+N −M) por líneas; `Write` solo cuenta líneas nuevas.
    static func fileChange(tool: String, input: [String: Any]) -> (String, FileChange)? {
        guard let path = input["file_path"] as? String else { return nil }
        switch tool {
        case "Edit":
            return (path, FileChange(added: lines(input["new_string"]), removed: lines(input["old_string"])))
        case "MultiEdit":
            let edits = input["edits"] as? [[String: Any]] ?? []
            return (path, FileChange(added: edits.reduce(0) { $0 + lines($1["new_string"]) },
                                     removed: edits.reduce(0) { $0 + lines($1["old_string"]) }))
        case "Write":
            return (path, FileChange(added: lines(input["content"]), removed: 0))
        default:
            return nil
        }
    }

    private static func lines(_ value: Any?) -> Int {
        guard let text = value as? String, !text.isEmpty else { return 0 }
        return text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}

@MainActor
final class SessionTracker: ObservableObject {
    static let shared = SessionTracker()

    @Published private(set) var sessions: [SessionInfo] = []
    private var store: [String: SessionInfo] = [:]

    func apply(_ event: SessionEvent) {
        SessionReducer.apply(event, to: &store)
        sessions = store.values.sorted { $0.lastActivity > $1.lastActivity }
    }
}
