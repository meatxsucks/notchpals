import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

enum ClaudeError: LocalizedError {
    case missingKey
    case api(String)
    case refusal

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Falta la API key de Anthropic."
        case .api(let message): return message
        case .refusal: return "Claude rechazó responder a esta petición."
        }
    }
}

/// Cliente mínimo de la Messages API por HTTP (Swift no tiene SDK oficial).
struct ClaudeClient {
    static let model = "claude-opus-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    var apiKey: String
    var session: URLSession = .shared

    static func makeRequest(apiKey: String, messages: [ChatMessage]) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16_000,
            "output_config": ["effort": "low"], // chat rápido en el notch
            "fallbacks": "default",
            "system": "Eres un asistente integrado en el notch de un Mac. Responde breve y directo.",
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseReply(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.api("Respuesta inesperada de la API.")
        }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw ClaudeError.api(message)
        }
        if json["stop_reason"] as? String == "refusal" { throw ClaudeError.refusal }
        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
        guard !text.isEmpty else { throw ClaudeError.api("La respuesta no trae texto.") }
        return text
    }

    func send(_ messages: [ChatMessage]) async throws -> String {
        let request = try Self.makeRequest(apiKey: apiKey, messages: messages)
        let (data, _) = try await session.data(for: request)
        return try Self.parseReply(data)
    }
}
