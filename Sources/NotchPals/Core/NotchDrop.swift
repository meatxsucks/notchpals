import SwiftUI
import UniformTypeIdentifiers

enum NotchDrop {
    /// Se publica al soltar un archivo en el notch; el Core puede abrir la pestaña Chat.
    static let didDrop = Notification.Name("NotchPalsDidDropFile")
}

struct NotchFileDrop: ViewModifier {
    @Binding var isTargeted: Bool

    func body(content: Content) -> some View {
        content.onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) })
            else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                Task { @MainActor in
                    ChatViewModel.shared.attach(url: url)
                    NotificationCenter.default.post(name: NotchDrop.didDrop, object: nil)
                }
            }
            return true
        }
    }
}

extension View {
    func notchFileDrop(isTargeted: Binding<Bool>) -> some View {
        modifier(NotchFileDrop(isTargeted: isTargeted))
    }
}
