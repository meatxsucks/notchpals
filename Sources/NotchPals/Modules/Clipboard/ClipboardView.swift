import SwiftUI

struct ClipboardView: View {
    @ObservedObject private var store = ClipboardStore.shared

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Portapapeles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Button("Limpiar") { store.clearUnpinned() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            if store.items.isEmpty {
                Spacer()
                Text("Nada copiado todavía")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(store.items) { item in
                            ClipboardRow(item: item)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 600, height: 150)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear { store.start() }
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    @ObservedObject private var store = ClipboardStore.shared
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.copy(item)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
            } label: {
                HStack {
                    Text(item.text.replacingOccurrences(of: "\n", with: " "))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    Spacer(minLength: 0)
                    if copied {
                        Text("Copiado")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { store.togglePin(item) } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundColor(item.isPinned ? .yellow : .white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Button { store.remove(item) } label: {
                Image(systemName: "trash")
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(hovering ? 0.14 : 0.07)))
        .onHover { hovering = $0 }
    }
}
