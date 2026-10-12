import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()

    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var attachment: Attachment?
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

    func send() {
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pending = attachment
        let text = typed.isEmpty && pending != nil ? "Describe este archivo." : typed
        guard !text.isEmpty, !isSending else { return }
        guard let key = KeychainStore.load() else { error = ClaudeError.missingKey.errorDescription; return }
        input = ""
        attachment = nil
        error = nil
        messages.append(ChatMessage(role: .user, text: text, attachment: pending))
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
