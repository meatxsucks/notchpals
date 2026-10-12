import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    let modules: [NotchModule]
    @Published private(set) var isExpanded = false
    @Published var selectedID: String

    private var isHovering = false
    private var needsAttention = false

    init(modules: [NotchModule]) {
        self.modules = modules
        self.selectedID = modules.first?.id ?? ""
    }

    var selected: NotchModule? { modules.first { $0.id == selectedID } }

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        updateExpanded()
    }

    /// Mantiene el notch abierto mientras algo requiera al usuario (p. ej. una aprobación).
    func setNeedsAttention(_ value: Bool, focusing moduleID: String? = nil) {
        needsAttention = value
        if value, let moduleID { selectedID = moduleID }
        updateExpanded()
    }

    private func updateExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = isHovering || needsAttention
        }
    }
}
