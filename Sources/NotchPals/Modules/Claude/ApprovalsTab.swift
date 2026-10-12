import SwiftUI

struct ApprovalsTab: View {
    @ObservedObject private var approvals = ApprovalServer.shared
    @AppStorage(ApprovalServer.soundDefaultsKey) private var soundEnabled = true

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(approvals.pending.isEmpty ? "" : "\(approvals.pending.count) pendiente(s)")
                    .font(.caption).foregroundStyle(.gray)
                Spacer()
                Toggle("Sonido", isOn: $soundEnabled)
                    .toggleStyle(.switch).controlSize(.mini).font(.caption)
            }
            if approvals.pending.isEmpty {
                Spacer()
                Text(approvals.isRunning ? "Sin solicitudes de Claude Code" : "Servidor de aprobaciones detenido")
                    .font(.callout).foregroundStyle(.gray)
                Spacer()
            } else {
                let items = approvals.pending
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ApprovalRow(item: item, position: index + 1, total: items.count,
                                        isFirst: index == 0) { decision in
                                approvals.resolve(item.id, decision: decision)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 600, maxHeight: 150)
    }
}

private struct ApprovalRow: View {
    let item: ApprovalServer.Pending
    let position: Int
    let total: Int
    let isFirst: Bool
    let onDecision: (ApprovalDecision) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(position) de \(total)").font(.caption2).foregroundStyle(.gray)
                    Text(item.request.tool).font(.callout.bold())
                }
                Text(item.request.summary).font(.caption).foregroundStyle(.gray).lineLimit(2)
            }
            Spacer()
            if isFirst {
                // Atajos solo para la primera de la cola: ⎋ rechaza, ⌘↩ permite.
                denyButton.keyboardShortcut(.cancelAction)
                alwaysButton
                allowButton.keyboardShortcut(.return, modifiers: .command)
            } else {
                denyButton
                alwaysButton
                allowButton
            }
        }
    }

    private var denyButton: some View {
        Button("Rechazar") { onDecision(.deny) }.tint(.red)
    }

    @ViewBuilder private var alwaysButton: some View {
        if item.request.suggestions != nil {
            Button("Siempre") { onDecision(.always) }.tint(.blue)
        }
    }

    private var allowButton: some View {
        Button("Permitir") { onDecision(.allow) }.tint(.green)
    }
}
