import SwiftUI

struct ChatTab: View {
    @ObservedObject private var chat = ChatViewModel.shared
    @State private var keyDraft = ""

    @ViewBuilder var body: some View {
        if !chat.hasKey {
            HStack {
                SecureField("API key de Anthropic (sk-ant-…)", text: $keyDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Guardar") { chat.saveKey(keyDraft); keyDraft = "" }
            }
            Text("Se guarda en el llavero de macOS.").font(.caption).foregroundStyle(.gray)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(chat.messages) { message in
                        Text(message.attachment.map { "📎 \($0.name)\n" + message.text } ?? message.text)
                            .font(.callout)
                            .foregroundStyle(message.role == .user ? .gray : .white)
                            .textSelection(.enabled)
                    }
                    if chat.isSending { ProgressView().controlSize(.small) }
                    if let error = chat.error { Text(error).font(.caption).foregroundStyle(.red) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let attachment = chat.attachment {
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                    Text(attachment.name).lineLimit(1).truncationMode(.middle)
                    Button { chat.removeAttachment() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.15)))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                TextField("Pregúntale a Claude…", text: $chat.input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { chat.send() }
                Button { chat.clear() } label: { Image(systemName: "trash") }.buttonStyle(.plain)
            }
        }
    }
}
