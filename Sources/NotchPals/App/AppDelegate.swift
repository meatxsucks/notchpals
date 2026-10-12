import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // sin ícono en el Dock
        let viewModel = NotchViewModel(modules: ModuleRegistry.all)
        panelController = NotchPanelController(viewModel: viewModel)
        panelController?.show()

        // Aprobaciones de Claude Code: abren el notch y lo mantienen abierto hasta decidir.
        ApprovalServer.shared.start()
        ApprovalServer.shared.$pending
            .map { !$0.isEmpty }
            .removeDuplicates()
            .sink { viewModel.setNeedsAttention($0, focusing: "claude") }
            .store(in: &cancellables)
    }
}
