import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    let modules: [NotchModule]
    @Published var isExpanded = false
    @Published var selectedID: String

    init(modules: [NotchModule]) {
        self.modules = modules
        self.selectedID = modules.first?.id ?? ""
    }

    var selected: NotchModule? { modules.first { $0.id == selectedID } }
}
