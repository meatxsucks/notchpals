import SwiftUI

struct HookTab: View {
    @ObservedObject private var installer = HookInstallModel.shared

    @ViewBuilder var body: some View {
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
