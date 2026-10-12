import SwiftUI

/// Contenedor con pestañas; cada pestaña vive en su propio archivo (ChatTab, SessionsTab, ApprovalsTab, HookTab).
struct ClaudeView: View {
    @ObservedObject private var approvals = ApprovalServer.shared
    @State private var tab = 0

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
            case 0: ChatTab()
            case 1: SessionsTab()
            case 2: ApprovalsTab()
            default: HookTab()
            }
        }
        .frame(maxWidth: 600, maxHeight: 150)
        .foregroundStyle(.white)
        .onChange(of: approvals.pending.count) { count in if count > 0 { tab = 2 } }
    }
}
