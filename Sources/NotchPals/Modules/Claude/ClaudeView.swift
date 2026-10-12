import SwiftUI

struct ClaudeView: View {
    @ObservedObject private var chat = ChatViewModel.shared
    @ObservedObject private var approvals = ApprovalServer.shared
    @ObservedObject private var sessions = SessionTracker.shared
    @ObservedObject private var installer = HookInstallModel.shared
    @State private var tab = 0
    @State private var keyDraft = ""

    var body: some View {
        VStack(spacing: 6) {
            Picker("", selection: $tab) {
                Text("Chat").tag(0)
                Text("Sesiones").tag(1)
                Text(approvals.pending.isEmpty ? "Aprobaciones" : "Aprobaciones (\(approvals.pending.count))").tag(2)
                Text("Hook").tag(3)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch tab {
            case 0: chatView
            case 1: sessionsView
            case 2: approvalsView
            default: hookView
            }
        }
        .frame(maxWidth: 600, maxHeight: 150)
        .foregroundStyle(.white)
        .onChange(of: approvals.pending.count) { count in if count > 0 { tab = 2 } }
    }

    // MARK: - Chat

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

    // MARK: - Sesiones en vivo

    @ViewBuilder private var sessionsView: some View {
        if sessions.sessions.isEmpty {
            Spacer()
            Text(installer.isInstalled ? "Sin sesiones activas de Claude Code" : "Instala el hook (pestaña Hook) para ver tus sesiones")
                .font(.callout).foregroundStyle(.gray)
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(sessions.sessions) { session in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(session.state == .working ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(session.project).font(.callout.bold())
                                Text(session.action).font(.caption).foregroundStyle(.gray).lineLimit(1)
                            }
                            Spacer()
                            if !session.changes.isEmpty {
                                Text("\(session.changes.count) arch. ")
                                    .font(.caption).foregroundStyle(.gray)
                                + Text("+\(session.totalAdded) ").font(.caption).foregroundStyle(.green)
                                + Text("−\(session.totalRemoved)").font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Aprobaciones

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
                            if item.request.suggestions != nil {
                                Button("Siempre") { approvals.resolve(item.id, decision: .always) }.tint(.blue)
                            }
                            Button("Permitir") { approvals.resolve(item.id, decision: .allow) }.tint(.green)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Instalar hook

    @ViewBuilder private var hookView: some View {
        if let preview = installer.preview {
            Text("Se modificará ~/.claude/settings.json (con copia de seguridad):")
                .font(.caption).foregroundStyle(.gray)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(preview.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(line.hasPrefix("+") ? .green : .red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Cancelar") { installer.cancel() }
                Spacer()
                Button("Confirmar") { installer.confirm() }.tint(.green)
            }
        } else {
            Spacer()
            HStack {
                Image(systemName: installer.isInstalled ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(installer.isInstalled ? .green : .gray)
                Text(installer.isInstalled ? "Hook instalado" : "Hook sin instalar").font(.callout)
                Spacer()
                if installer.isInstalled {
                    Button("Quitar") { installer.prepare(.remove) }
                } else {
                    Button("Instalar…") { installer.prepare(.install) }
                }
            }
            if let message = installer.message { Text(message).font(.caption).foregroundStyle(.gray) }
            Spacer()
        }
    }
}
