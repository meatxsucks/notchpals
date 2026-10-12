import Combine
import Foundation

/// Reúne las señales de la app (aprobaciones, sesiones, música, arrastre) y decide el humor de Dot.
@MainActor
final class MascotModel: ObservableObject {
    static let shared = MascotModel()

    @Published private(set) var mood: MascotMood = .idle

    var isDraggingFile = false { didSet { update() } }

    private var hasPendingApproval = false
    private var isWorking = false
    private var isMusicPlaying = false
    private var justFinished = false
    private var cancellables = Set<AnyCancellable>()
    private var finishTask: Task<Void, Never>?

    init() {
        ApprovalServer.shared.$pending
            .sink { [weak self] pending in
                self?.hasPendingApproval = !pending.isEmpty
                self?.update()
            }
            .store(in: &cancellables)

        SessionTracker.shared.$sessions
            .sink { [weak self] sessions in
                guard let self else { return }
                let working = sessions.contains { $0.state == .working }
                if self.isWorking && !working { self.flashFinished() }
                self.isWorking = working
                self.update()
            }
            .store(in: &cancellables)

        MusicService.shared.$snapshot
            .sink { [weak self] snapshot in
                self?.isMusicPlaying = snapshot?.state == .playing
                self?.update()
            }
            .store(in: &cancellables)
    }

    private func flashFinished() {
        justFinished = true
        finishTask?.cancel()
        finishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.justFinished = false
            self?.update()
        }
    }

    private func update() {
        let next = MascotMood.resolve(hasPendingApproval: hasPendingApproval, isWorking: isWorking,
                                      isMusicPlaying: isMusicPlaying, isDraggingFile: isDraggingFile,
                                      justFinished: justFinished)
        if next != mood { mood = next }
    }
}
