import Foundation

enum AttachmentError: LocalizedError, Equatable {
    case unsupported(String)
    case tooLarge(name: String, limit: Int)
    case unreadable(String)
    case notUTF8(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let name):
            return "«\(name)» no es un tipo de archivo compatible (texto, código, imagen PNG/JPEG/GIF/WebP o PDF)."
        case .tooLarge(let name, let limit):
            return "«\(name)» es demasiado grande (máximo \(Attachment.formatSize(limit)))."
        case .unreadable(let name):
            return "No se pudo leer «\(name)»."
        case .notUTF8(let name):
            return "«\(name)» no es texto UTF-8 válido."
        }
    }
}

/// Archivo adjunto a un mensaje de usuario.
struct Attachment: Equatable, Sendable {
    enum Category: Equatable, Sendable {
        case text
        case image(mediaType: String)
        case pdf
    }

    enum Payload: Equatable, Sendable {
        case text(String)
        case base64(String)
    }

    static let maxTextBytes = 200 * 1024
    static let maxImageBytes = 5 * 1024 * 1024
    static let maxPDFBytes = 10 * 1024 * 1024

    static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "yaml", "yml", "toml", "xml", "csv", "tsv", "log", "ini", "cfg", "conf",
        "swift", "m", "h", "c", "cc", "cpp", "hpp", "rs", "go", "py", "rb", "js", "mjs", "ts", "tsx", "jsx",
        "java", "kt", "cs", "php", "sh", "zsh", "bash", "sql", "html", "htm", "css", "scss", "lua", "pl", "r",
        "gradle", "plist", "env", "gitignore", "tex", "rst",
    ]
    static let textFileNames: Set<String> = ["makefile", "dockerfile", "readme", "license", "gemfile", "podfile"]

    let name: String
    let category: Category
    let payload: Payload

    // MARK: Clasificación y límites (puros)

    static func category(forFileName name: String) -> Category? {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return .image(mediaType: "image/png")
        case "jpg", "jpeg": return .image(mediaType: "image/jpeg")
        case "gif": return .image(mediaType: "image/gif")
        case "webp": return .image(mediaType: "image/webp")
        case "pdf": return .pdf
        default:
            if textExtensions.contains(ext) { return .text }
            if ext.isEmpty, textFileNames.contains(name.lowercased()) { return .text }
            return nil
        }
    }

    static func maxBytes(for category: Category) -> Int {
        switch category {
        case .text: return maxTextBytes
        case .image: return maxImageBytes
        case .pdf: return maxPDFBytes
        }
    }

    /// Valida nombre y tamaño sin leer el contenido.
    static func validate(name: String, size: Int) throws -> Category {
        guard let category = category(forFileName: name) else { throw AttachmentError.unsupported(name) }
        let limit = maxBytes(for: category)
        guard size <= limit else { throw AttachmentError.tooLarge(name: name, limit: limit) }
        return category
    }

    static func formatSize(_ bytes: Int) -> String {
        bytes >= 1024 * 1024 ? "\(bytes / (1024 * 1024)) MB" : "\(bytes / 1024) KB"
    }

    // MARK: Construcción

    static func make(name: String, data: Data) throws -> Attachment {
        let category = try validate(name: name, size: data.count)
        switch category {
        case .text:
            guard let text = String(data: data, encoding: .utf8) else { throw AttachmentError.notUTF8(name) }
            return Attachment(name: name, category: category, payload: .text(text))
        case .image, .pdf:
            return Attachment(name: name, category: category, payload: .base64(data.base64EncodedString()))
        }
    }

    static func load(url: URL) throws -> Attachment {
        let name = url.lastPathComponent
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            _ = try validate(name: name, size: size) // falla antes de leer archivos enormes
        }
        guard let data = try? Data(contentsOf: url) else { throw AttachmentError.unreadable(name) }
        return try make(name: name, data: data)
    }

    // MARK: Bloques de la Messages API

    /// Bloques de contenido: primero el archivo, luego el texto del usuario.
    func contentBlocks(prompt: String) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        switch (category, payload) {
        case (.image(let mediaType), .base64(let data)):
            blocks.append(["type": "image", "source": ["type": "base64", "media_type": mediaType, "data": data]])
        case (.pdf, .base64(let data)):
            blocks.append(["type": "document", "source": ["type": "base64", "media_type": "application/pdf", "data": data]])
        case (_, .text(let text)):
            blocks.append(["type": "text", "text": "Archivo adjunto «\(name)»:\n\n\(text)"])
        default:
            break
        }
        blocks.append(["type": "text", "text": prompt])
        return blocks
    }
}
