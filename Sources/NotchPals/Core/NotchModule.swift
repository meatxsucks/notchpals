import SwiftUI

/// Contrato que implementa cada herramienta del notch.
/// Cada módulo vive en `Modules/<Nombre>/` y se registra en `ModuleRegistry`.
protocol NotchModule {
    var id: String { get }
    var title: String { get }
    var systemImage: String { get }
    @MainActor func makeView() -> AnyView
}
