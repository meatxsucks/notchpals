import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // sin ícono en el Dock
        panelController = NotchPanelController(viewModel: NotchViewModel(modules: ModuleRegistry.all))
        panelController?.show()
    }
}
