import SwiftUI

struct ApprovalsTab: View {
    @ObservedObject private var approvals = ApprovalServer.shared

    @ViewBuilder var body: some View {
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
}
