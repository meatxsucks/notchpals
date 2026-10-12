import SwiftUI

struct SessionsTab: View {
    @ObservedObject private var sessions = SessionTracker.shared
    @ObservedObject private var installer = HookInstallModel.shared

    @ViewBuilder var body: some View {
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
}
