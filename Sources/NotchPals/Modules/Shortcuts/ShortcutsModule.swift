import SwiftUI

struct ShortcutsModule: NotchModule {
    let id = "shortcuts"
    let title = "Atajos"
    let systemImage = "bolt.fill"

    @MainActor func makeView() -> AnyView {
        AnyView(ShortcutsView())
    }
}
