import SwiftUI

struct ClaudeView: View {
    @ObservedObject private var chat = ChatViewModel.shared
    @ObservedObject private var approvals = ApprovalServer.shared
    @State private var tab = 0
    @State private var keyDraft = ""

    var body: some View {
        VStack(spacing: 6) {
            Picker("", selection: $tab) {
                Text("Chat").tag(0)
                Text(approvals.pending.isEmpty ? "Aprobaciones" : "Aprobaciones (\(approvals.pending.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if tab == 0 { chatView } else { approvalsView }
        }
        .frame(maxWidth: 600, maxHeight: 150)
        .foregroundStyle(.white)
        .onChange(of: approvals.pending.count) { count in if count > 0 { tab = 1 } }
    }

    @ViewBuilder private var chatView: some View {
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
                        Text(message.text)
                            .font(.callout)
                            .foregroundStyle(message.role == .user ? .gray : .white)
                            .textSelection(.enabled)
                    }
                    if chat.isSending { ProgressView().controlSize(.small) }
                    if let error = chat.error { Text(error).font(.caption).foregroundStyle(.red) }
                }
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

    @ViewBuilder private var approvalsView: some View {
        if approvals.pending.isEmpty {
            Spacer()
            Text(approvals.isRunning ? "Sin solicitudes de Claude Code" : "Servidor de aprobaciones detenido")
                .font(.callout).foregroundStyle(.gray)
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(approvals.pending) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.request.tool).font(.callout.bold())
                                Text(item.request.summary).font(.caption).foregroundStyle(.gray).lineLimit(2)
                            }
                            Spacer()
                            Button("Rechazar") { approvals.resolve(item.id, decision: .deny) }.tint(.red)
                            Button("Permitir") { approvals.resolve(item.id, decision: .allow) }.tint(.green)
                        }
                    }
                }
            }
        }
    }
}
