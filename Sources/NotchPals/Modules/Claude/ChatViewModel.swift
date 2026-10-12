import SwiftUI

enum ChatProvider: String, CaseIterable, Identifiable {
    case claude, ollama, lmstudio

    var id: String { rawValue }
    var label: String {
        switch self {
        case .claude: return "Claude"
        case .ollama: return LocalServer.ollama.label
        case .lmstudio: return LocalServer.lmstudio.label
        }
    }
    var server: LocalServer? { LocalServer(rawValue: rawValue) }
    var isLocal: Bool { server != nil }
    var urlKey: String { "notchpals.\(rawValue).url" }
    var modelKey: String { "notchpals.\(rawValue).model" }
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
            loadLocalSettings()
        }
    }
    /// URL que se está editando; solo se guarda al conectar con éxito.
    @Published var localURL = ""
    @Published var localModels: [String] = []
    @Published var localModel = "" {
        didSet { if provider.isLocal { UserDefaults.standard.set(localModel, forKey: provider.modelKey) } }
    }
    @Published var isConnecting = false

    private var sendTask: Task<Void, Never>?

    init() {
        provider = ChatProvider(rawValue: UserDefaults.standard.string(forKey: Self.providerKey) ?? "") ?? .claude
        loadLocalSettings()
    }

    // MARK: Claude

    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasKey = KeychainStore.save(trimmed)
    }

    func forgetKey() {
        KeychainStore.delete()
        hasKey = false
    }

    // MARK: Servidores locales

    /// URL guardada del proveedor actual, ya normalizada; vacía si no está conectado.
    private var savedURL: String { UserDefaults.standard.string(forKey: provider.urlKey) ?? "" }

    private func loadLocalSettings() {
        guard let server = provider.server else { return }
        localURL = savedURL.isEmpty ? server.defaultURL : savedURL
        localModel = UserDefaults.standard.string(forKey: provider.modelKey) ?? ""
        localModels = []
        if !savedURL.isEmpty { connect() }
    }

    /// Prueba la URL, lista los modelos y, si responde, la guarda.
    func connect() {
        guard provider.isLocal, !isConnecting else { return }
        let target = provider
        let url = LocalLLM.normaliseURL(localURL)
        isConnecting = true
        error = nil
        Task {
            defer { isConnecting = false }
            do {
                let models = try await LocalLLMClient(baseURL: url, model: "").listModels()
                guard provider == target else { return }
                localURL = url
                UserDefaults.standard.set(url, forKey: target.urlKey)
                localModels = models
                if !models.contains(localModel) { localModel = models.first ?? "" }
                if models.isEmpty { error = "El servidor no tiene modelos de chat instalados." }
            } catch {
                guard provider == target else { return }
                localModels = []
                self.error = error.localizedDescription
            }
        }
    }

    /// Olvida la conexión del proveedor actual.
    func disconnect() {
        guard let server = provider.server else { return }
        UserDefaults.standard.removeObject(forKey: provider.urlKey)
        localModels = []
        localURL = server.defaultURL
        error = nil
    }

    // MARK: Adjuntos

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

    // MARK: Envío

    func send() {
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pending = attachment
        let text = typed.isEmpty && pending != nil ? "Describe este archivo." : typed
        guard !text.isEmpty, !isSending else { return }
        if provider == .claude, KeychainStore.load() == nil {
            error = ClaudeError.missingKey.errorDescription
            return
        }
        if provider.isLocal, localModel.isEmpty {
            error = LocalLLMError.noModel.errorDescription
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
                if provider == .claude {
                    let reply = try await ClaudeClient(apiKey: KeychainStore.load() ?? "").send(history)
                    messages.append(ChatMessage(role: .assistant, text: reply))
                } else {
                    messages.append(ChatMessage(role: .assistant, text: ""))
                    let client = LocalLLMClient(baseURL: LocalLLM.normaliseURL(localURL), model: localModel)
                    for try await visible in client.streamReply(history) {
                        messages[messages.count - 1].text = visible
                    }
                    if messages.last?.text.isEmpty == true { messages.removeLast() }
                }
            } catch {
                if messages.last?.role == .assistant, messages.last?.text.isEmpty == true { messages.removeLast() }
                if !(error is CancellationError) { self.error = error.localizedDescription }
            }
            isSending = false
        }
    }

    func stop() { sendTask?.cancel() }

    func clear() { messages = []; error = nil }
}
