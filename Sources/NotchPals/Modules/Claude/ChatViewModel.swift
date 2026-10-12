import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()

    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var isSending = false
    @Published var error: String?
    @Published var hasKey = KeychainStore.load() != nil

    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasKey = KeychainStore.save(trimmed)
    }

    func forgetKey() {
        KeychainStore.delete()
        hasKey = false
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard let key = KeychainStore.load() else { error = ClaudeError.missingKey.errorDescription; return }
        input = ""
        error = nil
        messages.append(ChatMessage(role: .user, text: text))
        isSending = true
        let history = messages
        Task {
            do {
                let reply = try await ClaudeClient(apiKey: key).send(history)
                messages.append(ChatMessage(role: .assistant, text: reply))
            } catch {
                self.error = error.localizedDescription
            }
            isSending = false
        }
    }

    func clear() { messages = []; error = nil }
}
