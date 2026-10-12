import AppKit
import SwiftUI
import Combine

/// Panel flotante pegado al borde superior central. Se redimensiona al expandirse.
@MainActor
final class NotchPanelController {
    static let expandedSize = CGSize(width: 640, height: 220)

    private let viewModel: NotchViewModel
    private let panel: NSPanel
    private var cancellable: AnyCancellable?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        panel = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .mainMenu + 3
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: NotchRootView(viewModel: viewModel))
        cancellable = viewModel.$isExpanded.sink { [weak self] expanded in
            self?.updateFrame(expanded: expanded, animated: true)
        }
    }

    func show() {
        updateFrame(expanded: false, animated: false)
        panel.orderFrontRegardless()
    }

    private func updateFrame(expanded: Bool, animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let notch = screen.notchSize
        let size = expanded ? Self.expandedSize : notch
        let origin = CGPoint(x: screen.frame.midX - size.width / 2,
                             y: screen.frame.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: true, animate: animated)
    }
}
