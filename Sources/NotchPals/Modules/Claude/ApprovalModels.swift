import Foundation

struct ApprovalRequest: Identifiable, Equatable {
    let id = UUID()
    let tool: String
    let summary: String
    let cwd: String?
    /// `permission_suggestions` de Claude Code (JSON ya serializado); permite el botón «Siempre».
    var suggestions: Data? = nil
}

enum ApprovalDecision: String {
    case allow, always, deny, ask
}

/// Formato del hook `PermissionRequest` de Claude Code (entrada JSON por stdin, salida JSON por stdout).
/// Solo se dispara cuando Claude Code realmente va a pedir permiso.
enum ApprovalProtocol {
    static func parse(_ data: Data) -> ApprovalRequest? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = json["tool_name"] as? String else { return nil }
        let input = json["tool_input"] as? [String: Any] ?? [:]
        var suggestions: Data?
        if let list = json["permission_suggestions"] as? [Any], !list.isEmpty {
            suggestions = try? JSONSerialization.data(withJSONObject: list)
        }
        return ApprovalRequest(tool: tool, summary: summarize(tool: tool, input: input),
                               cwd: json["cwd"] as? String, suggestions: suggestions)
    }

    static func summarize(tool: String, input: [String: Any]) -> String {
        let text: String
        if let command = input["command"] as? String {
            text = command
        } else if let path = input["file_path"] as? String {
            text = path
        } else if let data = try? JSONSerialization.data(withJSONObject: input, options: [.sortedKeys]),
                  let raw = String(data: data, encoding: .utf8) {
            text = raw
        } else {
            text = ""
        }
        return text.count > 200 ? String(text.prefix(200)) + "…" : text
    }

    /// JSON que imprime el hook. `nil` = sin salida: Claude Code muestra su diálogo normal.
    static func responseJSON(_ decision: ApprovalDecision, request: ApprovalRequest) -> Data? {
        var inner: [String: Any]
        switch decision {
        case .ask:
            return nil
        case .allow:
            inner = ["behavior": "allow"]
        case .always:
            inner = ["behavior": "allow"]
            if let data = request.suggestions,
               let list = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                inner["updatedPermissions"] = list
            }
        case .deny:
            inner = ["behavior": "deny", "message": "Rechazado desde NotchPals"]
        }
        let payload: [String: Any] = [
            "hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": inner]
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}

/// Parser mínimo de HTTP/1.1: devuelve nil mientras la petición esté incompleta.
enum HTTPRequestParser {
    struct Request {
        let method: String
        let path: String
        let headers: [String: String] // claves en minúsculas
        let body: Data
    }

    static func parse(_ data: Data) -> Request? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator),
              let head = String(data: data[..<range.lowerBound], encoding: .utf8) else { return nil }
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].lowercased()
            headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        let body = data[range.upperBound...]
        guard body.count >= length else { return nil }
        return Request(method: String(requestLine[0]), path: String(requestLine[1]),
                       headers: headers, body: Data(body.prefix(length)))
    }
}
