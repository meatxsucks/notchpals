import Foundation

enum OllamaError: LocalizedError, Equatable {
    case api(String)
    case noModel
    case pdfUnsupported
    case unreachable(String)

    var errorDescription: String? {
        switch self {
        case .api(let message): return message
        case .noModel: return "Elige un modelo de Ollama."
        case .pdfUnsupported: return "Ollama no lee PDF directamente; adjunta texto o una imagen."
        case .unreachable(let url): return "No se pudo conectar con Ollama en \(url). ¿Está corriendo (ollama serve)?"
        }
    }
}

enum OllamaSettings {
    static let urlKey = "notchpals.ollamaURL"
    static let modelKey = "notchpals.ollamaModel"
    static let defaultURL = "http://127.0.0.1:11434"

    static var baseURL: URL {
        let raw = UserDefaults.standard.string(forKey: urlKey) ?? defaultURL
        return URL(string: raw.trimmingCharacters(in: .whitespaces)) ?? URL(string: defaultURL)!
    }
}

/// Cliente de la API local de Ollama (`/api/chat` con streaming y `/api/tags`).
struct OllamaClient {
    static let systemPrompt = "Eres un asistente integrado en el notch de un Mac. Responde breve y directo."

    var baseURL: URL
    var model: String
    var session: URLSession = .shared

    // MARK: Construcción y parseo (puros)

    static func makeChatRequest(baseURL: URL, model: String, messages: [ChatMessage]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 300 // los modelos locales pueden tardar en cargar
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        var encoded: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for message in messages { encoded.append(try encode(message)) }
        let body: [String: Any] = ["model": model, "messages": encoded, "stream": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func encode(_ message: ChatMessage) throws -> [String: Any] {
        var result: [String: Any] = ["role": message.role.rawValue, "content": message.text]
        guard let attachment = message.attachment else { return result }
        switch (attachment.category, attachment.payload) {
        case (.text, .text(let text)):
            result["content"] = "Archivo «\(attachment.name)»:\n\(text)\n\n\(message.text)"
        case (.image, .base64(let data)):
            result["images"] = [data]
        default:
            throw OllamaError.pdfUnsupported
        }
        return result
    }

    /// Una línea NDJSON del streaming; `nil` si está vacía.
    static func parseStreamLine(_ line: String) throws -> (text: String, done: Bool)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let json = try JSONSerialization.jsonObject(with: Data(trimmed.utf8)) as? [String: Any] else {
            throw OllamaError.api("Respuesta inesperada de Ollama.")
        }
        if let error = json["error"] as? String { throw OllamaError.api(error) }
        let text = (json["message"] as? [String: Any])?["content"] as? String ?? ""
        return (text, json["done"] as? Bool ?? false)
    }

    static func parseModels(_ data: Data) -> [String] {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = json?["models"] as? [[String: Any]] ?? []
        return models.compactMap { $0["name"] as? String }.sorted()
    }

    // MARK: Red

    func listModels() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.timeoutInterval = 5
        do {
            let (data, _) = try await session.data(for: request)
            return Self.parseModels(data)
        } catch is URLError {
            throw OllamaError.unreachable(baseURL.absoluteString)
        }
    }

    /// Emite el texto de la respuesta a medida que llega.
    func streamReply(_ messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.makeChatRequest(baseURL: baseURL, model: model, messages: messages)
                    let (bytes, response) = try await session.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        let message = (try? Self.parseStreamLine(body))?.text
                        throw OllamaError.api(message?.isEmpty == false ? message! : "Ollama respondió \(http.statusCode).")
                    }
                    for try await line in bytes.lines {
                        guard let chunk = try Self.parseStreamLine(line) else { continue }
                        if !chunk.text.isEmpty { continuation.yield(chunk.text) }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch is URLError {
                    continuation.finish(throwing: OllamaError.unreachable(baseURL.absoluteString))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
