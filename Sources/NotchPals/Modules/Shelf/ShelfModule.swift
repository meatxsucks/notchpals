import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShelfModule: NotchModule {
    let id = "shelf"
    let title = "Bandeja"
    let systemImage = "tray.and.arrow.down"

    @MainActor func makeView() -> AnyView {
        AnyView(ShelfView())
    }
}

struct ShelfView: View {
    @StateObject private var store = ShelfStore()
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Bandeja")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                if !store.items.isEmpty {
                    Button("Limpiar todo") { store.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        Color.white.opacity(isTargeted ? 0.7 : 0.2),
                        style: StrokeStyle(lineWidth: 1, dash: [5])
                    )
                if store.items.isEmpty {
                    Text("Arrastra archivos aquí")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.items) { item in
                                ShelfChip(item: item) { store.remove(item) }
                            }
                        }
                        .padding(8)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 600, height: 150)
        .background(Color.black)
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let u = item as? URL {
                    url = u
                }
                guard let url else { return }
                Task { @MainActor in store.add(urls: [url]) }
            }
        }
        return accepted
    }
}

private struct ShelfChip: View {
    let item: ShelfItem
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .frame(width: 40, height: 40)
                Text(item.name)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 72)
            }
            .padding(6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onDrag {
                NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(2)
        }
    }
}
