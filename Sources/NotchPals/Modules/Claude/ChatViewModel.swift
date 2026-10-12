import SwiftUI

enum ChatProvider: String, CaseIterable, Identifiable {
    case claude, ollama
    var id: String { rawValue }
    var label: String { self == .claude ? "Claude" : "Ollama" }
}

@MainActor
final class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()

    private static let providerKey = "notchpals.chatProvider"

    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var attachment: Attachment?
    @Published var isSending = false
    @Published var error: String?
    @Published var hasKey = KeychainStore.load() != nil

    @Published var provider: ChatProvider {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey)
            error = nil
            if provider == .ollama { refreshModels() }
        }
    }
    @Published var ollamaModels: [String] = []
    @Published var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: OllamaSettings.modelKey) }
    }
    @Published var ollamaURL: String {
        didSet { UserDefaults.standard.set(ollamaURL, forKey: OllamaSettings.urlKey) }
    }

    private var sendTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        provider = ChatProvider(rawValue: defaults.string(forKey: Self.providerKey) ?? "") ?? .claude
        ollamaModel = defaults.string(forKey: OllamaSettings.modelKey) ?? ""
        ollamaURL = defaults.string(forKey: OllamaSettings.urlKey) ?? OllamaSettings.defaultURL
    }

    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasKey = KeychainStore.save(trimmed)
    }

    func forgetKey() {
        KeychainStore.delete()
        hasKey = false
    }

    func attach(url: URL) {
        error = nil
        Task {
            do {
                attachment = try await Task.detached { try Attachment.load(url: url) }.value
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeAttachment() { attachment = nil }

    func refreshModels() {
        Task {
            do {
                let models = try await OllamaClient(baseURL: OllamaSettings.baseURL, model: "").listModels()
                ollamaModels = models
                if !models.contains(ollamaModel) { ollamaModel = models.first ?? "" }
                if models.isEmpty { error = "Ollama no tiene modelos instalados (ollama pull <modelo>)." }
            } catch {
                ollamaModels = []
                self.error = error.localizedDescription
            }
        }
    }

    func send() {
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pending = attachment
        let text = typed.isEmpty && pending != nil ? "Describe este archivo." : typed
        guard !text.isEmpty, !isSending else { return }
        if provider == .claude, KeychainStore.load() == nil {
            error = ClaudeError.missingKey.errorDescription
            return
        }
        if provider == .ollama, ollamaModel.isEmpty {
            error = OllamaError.noModel.errorDescription
            return
        }
        input = ""
        attachment = nil
        error = nil
        messages.append(ChatMessage(role: .user, text: text, attachment: pending))
        isSending = true
        let history = messages
        sendTask = Task {
            do {
                switch provider {
                case .claude:
                    let reply = try await ClaudeClient(apiKey: KeychainStore.load() ?? "").send(history)
                    messages.append(ChatMessage(role: .assistant, text: reply))
                case .ollama:
                    messages.append(ChatMessage(role: .assistant, text: ""))
                    let client = OllamaClient(baseURL: OllamaSettings.baseURL, model: ollamaModel)
                    for try await piece in client.streamReply(history) {
                        messages[messages.count - 1].text += piece
                    }
                    if messages.last?.text.isEmpty == true { messages.removeLast() }
                }
            } catch {
                if provider == .ollama, messages.last?.role == .assistant, messages.last?.text.isEmpty == true {
                    messages.removeLast()
                }
                self.error = error.localizedDescription
            }
            isSending = false
        }
    }

    func stop() { sendTask?.cancel() }

    func clear() { messages = []; error = nil }
}
