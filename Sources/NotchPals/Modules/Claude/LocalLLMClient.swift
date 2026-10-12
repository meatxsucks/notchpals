import Foundation

enum LocalLLMError: LocalizedError, Equatable {
    case unreachable(String)
    case modelNotFound(String)
    case server(String)
    case noModel
    case pdfUnsupported

    var errorDescription: String? {
        switch self {
        case .unreachable(let url): return "No se pudo conectar con \(url). ¿Está corriendo el servidor?"
        case .modelNotFound(let model): return "El modelo «\(model)» no está instalado."
        case .server(let message): return message
        case .noModel: return "Elige un modelo."
        case .pdfUnsupported: return "Los modelos locales no leen PDF; adjunta texto o una imagen."
        }
    }
}

/// Servidores locales con API compatible con OpenAI.
enum LocalServer: String, CaseIterable {
    case ollama, lmstudio

    var label: String { self == .ollama ? "Ollama" : "LM Studio" }
    var defaultURL: String { self == .ollama ? "http://127.0.0.1:11434" : "http://127.0.0.1:1234" }
}

/// Utilidades puras para hablar con un servidor local (Ollama, LM Studio…).
enum LocalLLM {
    /// Modelos que no sirven para chat.
    static let excludedModelHints = ["embed", "bge-", "all-minilm", "clip", "rerank"]

    /// Quita barras finales y los sufijos /api y /v1.
    static func normaliseURL(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") { url.removeLast() }
        for suffix in ["/api", "/v1"] where url.hasSuffix(suffix) { url.removeLast(suffix.count) }
        return url
    }

    /// Texto nuevo de una línea SSE (`data: {...}`); nil si no es un dato, es `[DONE]` o no trae contenido.
    static func parseSSEDelta(_ line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]", let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else { return nil }
        return content
    }

    /// Quita los bloques `<think>…</think>` de los modelos que razonan.
    static func removeThinking(_ text: String) -> String {
        text.replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
    }

    /// Para streaming: además oculta el bloque `<think>` que aún no se cerró.
    static func visibleText(_ text: String) -> String {
        let closed = removeThinking(text)
        if let open = closed.range(of: "<think>") { return String(closed[..<open.lowerBound]).trimmed }
        return closed.trimmed
    }

    static func parseModels(_ data: Data) -> [String] {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["data"] as? [[String: Any]] ?? []
        return items.compactMap { $0["id"] as? String }
            .filter { id in !excludedModelHints.contains { id.lowercased().contains($0) } }
            .sorted()
    }

    /// Mensaje de error del cuerpo de una respuesta no exitosa.
    static func parseErrorMessage(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let message = (json["error"] as? [String: Any])?["message"] as? String { return message }
        return json["error"] as? String
    }

    static func makeChatRequest(baseURL: String, model: String, messages: [ChatMessage]) throws -> URLRequest {
        guard let url = URL(string: baseURL + "/v1/chat/completions") else { throw LocalLLMError.unreachable(baseURL) }
        var request = URLRequest(url: url, timeoutInterval: 300) // los modelos locales tardan en cargar
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer ollama", forHTTPHeaderField: "Authorization")
        var encoded: [[String: Any]] = [["role": "system", "content": ChatPrompt.system]]
        for message in messages { encoded.append(try encode(message)) }
        let body: [String: Any] = ["model": model, "messages": encoded, "stream": true, "max_tokens": 8192]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func encode(_ message: ChatMessage) throws -> [String: Any] {
        guard let attachment = message.attachment else { return ["role": message.role.rawValue, "content": message.text] }
        switch (attachment.category, attachment.payload) {
        case (.text, .text(let text)):
            return ["role": message.role.rawValue,
                    "content": "Archivo «\(attachment.name)»:\n\(text)\n\n\(message.text)"]
        case (.image(let mediaType), .base64(let data)):
            let parts: [[String: Any]] = [
                ["type": "text", "text": message.text],
                ["type": "image_url", "image_url": ["url": "data:\(mediaType);base64,\(data)"]],
            ]
            return ["role": message.role.rawValue, "content": parts]
        default:
            throw LocalLLMError.pdfUnsupported
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct LocalLLMClient {
    var baseURL: String
    var model: String
    var session: URLSession = .shared

    func listModels() async throws -> [String] {
        guard let url = URL(string: baseURL + "/v1/models") else { throw LocalLLMError.unreachable(baseURL) }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue("Bearer ollama", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw LocalLLMError.unreachable(baseURL) }
            return LocalLLM.parseModels(data)
        } catch {
            throw LocalLLMError.unreachable(baseURL)
        }
    }

    /// Emite el texto visible acumulado (sin bloques de razonamiento), como máximo ~15 veces por segundo.
    func streamReply(_ messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try LocalLLM.makeChatRequest(baseURL: baseURL, model: model, messages: messages)
                    let bytes: URLSession.AsyncBytes
                    let response: URLResponse
                    do { (bytes, response) = try await session.bytes(for: request) }
                    catch { throw LocalLLMError.unreachable(baseURL) }

                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status == 404 { throw LocalLLMError.modelNotFound(model) }
                    if status != 200 {
                        var body = ""
                        for try await line in bytes.lines { body += line; if body.count > 4096 { break } }
                        throw LocalLLMError.server(LocalLLM.parseErrorMessage(body) ?? "HTTP \(status)")
                    }

                    var accumulated = ""
                    var lastYield = Date.distantPast
                    for try await line in bytes.lines {
                        guard let delta = LocalLLM.parseSSEDelta(line) else { continue }
                        accumulated += delta
                        if Date().timeIntervalSince(lastYield) >= 1.0 / 15.0 {
                            lastYield = Date()
                            continuation.yield(LocalLLM.visibleText(accumulated))
                        }
                    }
                    continuation.yield(LocalLLM.visibleText(accumulated))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
