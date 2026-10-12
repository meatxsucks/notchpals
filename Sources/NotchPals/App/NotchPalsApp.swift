import SwiftUI

@main
struct NotchPalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // App de barra de menú: sin ventana principal.
        MenuBarExtra("NotchPals", systemImage: "capsule.fill") {
            Button("Salir") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
