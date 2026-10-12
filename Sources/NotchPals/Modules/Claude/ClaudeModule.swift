import SwiftUI

struct ClaudeModule: NotchModule {
    let id = "claude"
    let title = "Claude"
    let systemImage = "sparkles"

    @MainActor func makeView() -> AnyView { AnyView(ClaudeView()) }
}
