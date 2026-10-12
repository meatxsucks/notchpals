import AppKit
import Foundation
import SwiftUI

/// Servicio observable: consulta los reproductores mientras la vista está visible.
@MainActor
final class MusicService: ObservableObject {
    @Published private(set) var snapshot: MusicSnapshot?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var message: String?

    private let backends: [MusicBackend]
    private let intervalNanos: UInt64
    private var pollTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var artworkTrackID: String?

    init(backends: [MusicBackend]? = nil, pollInterval: TimeInterval = 1.0) {
        self.backends = backends ?? MusicApp.allCases.map { ScriptedMusicBackend(app: $0) }
        self.intervalNanos = UInt64(max(0.05, pollInterval) * 1_000_000_000)
    }

    deinit {
        pollTask?.cancel()
        artworkTask?.cancel()
    }

    // MARK: - Polling

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh()
                let nanos = self.intervalNanos
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    var isPolling: Bool { pollTask != nil }

    // MARK: - Estado

    func refresh() {
        var snapshots: [MusicSnapshot] = []
        var errors: [MusicError] = []
        var anyRunning = false

        for backend in backends where backend.isRunning() {
            anyRunning = true
            do {
                snapshots.append(try backend.fetchSnapshot())
            } catch let error as MusicError {
                errors.append(error)
            } catch {
                errors.append(.scriptFailed(error.localizedDescription))
            }
        }

        let chosen = MusicPlayerChooser.choose(snapshots)
        let newMessage: String?
        if chosen != nil {
            newMessage = nil
        } else if anyRunning {
            newMessage = errors.first?.userMessage
        } else {
            newMessage = "Abre Spotify o Apple Music para ver la reproducción."
        }

        if snapshot != chosen { snapshot = chosen }
        if message != newMessage { message = newMessage }
        updateArtwork(for: chosen)
    }

    func perform(_ command: MusicCommand) {
        let target = snapshot.flatMap { snap in backends.first { $0.app == snap.app } }
            ?? backends.first { $0.isRunning() }
        guard let backend = target else {
            message = "Abre Spotify o Apple Music para ver la reproducción."
            return
        }
        do {
            try backend.send(command)
        } catch let error as MusicError {
            message = error.userMessage
            return
        } catch {
            message = MusicError.scriptFailed(error.localizedDescription).userMessage
            return
        }
        refresh()
    }

    // MARK: - Carátula

    private func updateArtwork(for snapshot: MusicSnapshot?) {
        guard let snap = snapshot, let track = snap.track else {
            artworkTask?.cancel()
            artworkTrackID = nil
            if artwork != nil { artwork = nil }
            return
        }
        guard track.id != artworkTrackID else { return }
        artworkTrackID = track.id
        artwork = nil
        artworkTask?.cancel()
        guard let backend = backends.first(where: { $0.app == snap.app }) else { return }
        let trackID = track.id
        artworkTask = Task { [weak self] in
            let image = await backend.artwork(for: track)
            guard let self, !Task.isCancelled, self.artworkTrackID == trackID else { return }
            self.artwork = image
        }
    }
}
