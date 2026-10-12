import Foundation

/// Estado de ánimo de Dot, la mascota del notch.
enum MascotMood: Equatable, CaseIterable {
    case idle, working, alert, happy, dancing, curious

    /// Resuelve el humor según prioridad:
    /// alert > curious (arrastrando archivo) > happy (terminó algo) > dancing (música) > working > idle.
    static func resolve(hasPendingApproval: Bool,
                        isWorking: Bool,
                        isMusicPlaying: Bool,
                        isDraggingFile: Bool,
                        justFinished: Bool) -> MascotMood {
        if hasPendingApproval { return .alert }
        if isDraggingFile { return .curious }
        if justFinished { return .happy }
        if isMusicPlaying { return .dancing }
        if isWorking { return .working }
        return .idle
    }
}
