import SwiftUI

struct ClipboardModule: NotchModule {
    let id = "clipboard"
    let title = "Portapapeles"
    let systemImage = "doc.on.clipboard"

    @MainActor func makeView() -> AnyView {
        ClipboardStore.shared.start()
        return AnyView(ClipboardView())
    }
}
