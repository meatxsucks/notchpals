import Foundation

/// Lógica pura para registrar/quitar el hook de NotchPals en `~/.claude/settings.json`
/// sin tocar nada más del archivo.
enum HookInstaller {
    /// Eventos de Claude Code que usa NotchPals y su timeout en segundos.
    static let events: [(name: String, timeout: Int)] = [
        ("PermissionRequest", 120), // bloqueante: espera tu clic en el notch
        ("PreToolUse", 5), ("PostToolUse", 5), ("SessionStart", 5), ("Stop", 5), ("SessionEnd", 5),
    ]

    enum InstallError: LocalizedError {
        case invalidJSON
        case unexpectedStructure(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "settings.json no es un JSON válido; no se modificó."
            case .unexpectedStructure(let key): return "La clave hooks.\(key) tiene un formato inesperado; no se modificó."
            }
        }
    }

    /// Script que ejecutan los hooks. Nunca bloquea a Claude Code: si la app no responde, no imprime nada.
    static let scriptSource = #"""
    #!/bin/bash
    # NotchPals · hook de Claude Code (generado por la app).
    TOKEN_FILE="$HOME/.notchpals/token"
    [ -f "$TOKEN_FILE" ] || exit 0
    PAYLOAD="$(cat)"
    TOKEN="$(cat "$TOKEN_FILE")"
    case "$PAYLOAD" in
      *'"hook_event_name":"PermissionRequest"'*|*'"hook_event_name": "PermissionRequest"'*)
        printf '%s' "$PAYLOAD" | curl -s --max-time 110 -X POST "http://127.0.0.1:47600/approve" \
          -H "x-notchpals-token: $TOKEN" -H "content-type: application/json" --data-binary @- || true ;;
      *)
        printf '%s' "$PAYLOAD" | curl -s --max-time 1 -X POST "http://127.0.0.1:47600/event" \
          -H "x-notchpals-token: $TOKEN" -H "content-type: application/json" --data-binary @- >/dev/null 2>&1 || true ;;
    esac
    exit 0
    """#

    static func parse(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InstallError.invalidJSON
        }
        return object
    }

    static func isInstalled(_ settings: [String: Any], command: String) -> Bool {
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        return events.allSatisfy { event in
            let groups = hooks[event.name] as? [[String: Any]] ?? []
            return groups.contains { containsCommand($0, command) }
        }
    }

    static func installing(into settings: [String: Any], command: String) throws -> [String: Any] {
        var settings = settings
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            guard hooks[event.name] == nil || hooks[event.name] is [[String: Any]] else {
                throw InstallError.unexpectedStructure(event.name)
            }
            var groups = hooks[event.name] as? [[String: Any]] ?? []
            if !groups.contains(where: { containsCommand($0, command) }) {
                groups.append(["hooks": [["type": "command", "command": command, "timeout": event.timeout]]])
            }
            hooks[event.name] = groups
        }
        settings["hooks"] = hooks
        return settings
    }

    static func removing(from settings: [String: Any], command: String) -> [String: Any] {
        var settings = settings
        guard var hooks = settings["hooks"] as? [String: Any] else { return settings }
        for (name, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            let kept: [[String: Any]] = groups.compactMap { group in
                var group = group
                let remaining = (group["hooks"] as? [[String: Any]] ?? []).filter { $0["command"] as? String != command }
                guard !remaining.isEmpty else { return nil }
                group["hooks"] = remaining
                return group
            }
            hooks[name] = kept.isEmpty ? nil : kept
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        return settings
    }

    /// Representación estable (claves ordenadas) para comparar antes y después.
    static func render(_ settings: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: settings,
                                                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Líneas quitadas («- ») y agregadas («+ »).
    static func diff(old: String, new: String) -> [String] {
        let a = old.components(separatedBy: "\n")
        let b = new.components(separatedBy: "\n")
        let changes = b.difference(from: a)
        var removed: [String] = []
        var inserted: [String] = []
        for change in changes {
            switch change {
            case .remove(_, let line, _): removed.append("- " + line)
            case .insert(_, let line, _): inserted.append("+ " + line)
            }
        }
        return removed + inserted
    }

    private static func containsCommand(_ group: [String: Any], _ command: String) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains { $0["command"] as? String == command }
    }
}
