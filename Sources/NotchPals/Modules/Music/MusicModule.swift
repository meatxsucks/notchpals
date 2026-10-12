import SwiftUI

struct MusicModule: NotchModule {
    let id = "music"
    let title = "Música"
    let systemImage = "music.note"

    @MainActor func makeView() -> AnyView {
        AnyView(MusicView())
    }
}
