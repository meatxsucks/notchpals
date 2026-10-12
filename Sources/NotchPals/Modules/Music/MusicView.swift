import AppKit
import SwiftUI

@MainActor
struct MusicView: View {
    @ObservedObject private var service: MusicService
    @State private var isVisible = false
    @State private var scrubFraction: Double?
    @State private var draftVolume: Double = 50
    @State private var editingVolume = false

    init(service: MusicService = MusicService.shared) {
        self.service = service
    }

    var body: some View {
        HStack(spacing: 14) {
            artworkView
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let snap = service.snapshot, let track = snap.track {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snap.app.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                    Text(track.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    progressRow(snap)
                    controls
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(emptyTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if let message = service.message {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if service.snapshot != nil { controls }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 600, maxHeight: 150)
        .background(Color.black)
        .onAppear {
            isVisible = true
            if let v = service.snapshot?.volume { draftVolume = Double(v) }
            service.acquire()
        }
        .onDisappear {
            isVisible = false
            service.release()
        }
        .onChange(of: service.snapshot?.volume) { newValue in
            if !editingVolume, let v = newValue { draftVolume = Double(v) }
        }
    }

    private var emptyTitle: String {
        service.snapshot == nil ? "Música" : "Nada en reproducción"
    }

    // MARK: - Progreso

    /// La interpolación solo corre con la vista visible y la música sonando;
    /// en reposo el `TimelineView` queda pausado y no consume CPU.
    private func progressRow(_ snap: MusicSnapshot) -> some View {
        let running = isVisible && snap.state == .playing && snap.duration > 0
        return TimelineView(.animation(minimumInterval: 0.5, paused: !running)) { context in
            let position = service.position(at: context.date)
            let fraction = scrubFraction
                ?? MusicProgress.fraction(position: position, duration: snap.duration)
            let shown = scrubFraction.map { $0 * snap.duration } ?? position
            HStack(spacing: 8) {
                Text(MusicProgress.format(shown))
                    .frame(width: 40, alignment: .trailing)
                ScrubBar(fraction: fraction,
                         enabled: snap.duration > 0,
                         scrub: $scrubFraction) { value in
                    service.seek(to: value * snap.duration)
                }
                Text(MusicProgress.format(snap.duration))
                    .frame(width: 40, alignment: .leading)
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Controles

    private var controls: some View {
        let snap = service.snapshot
        let caps = service.capabilities
        return HStack(spacing: 14) {
            if caps.shuffle, let shuffle = snap?.shuffle {
                toggleButton("shuffle", active: shuffle) { service.toggleShuffle() }
            }
            controlButton("backward.fill", size: 16) { service.perform(.previous) }
            controlButton(snap?.state == .playing ? "pause.fill" : "play.fill", size: 22) {
                service.perform(.playPause)
            }
            controlButton("forward.fill", size: 16) { service.perform(.next) }
            if caps.supportsRepeat, let mode = snap?.repeatMode {
                toggleButton(mode == .one ? "repeat.1" : "repeat", active: mode != .off) {
                    service.cycleRepeat()
                }
            }
            Spacer(minLength: 4)
            if caps.volume, snap?.volume != nil {
                volumeControl
            }
        }
    }

    private var volumeControl: some View {
        HStack(spacing: 5) {
            Image(systemName: draftVolume <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 16)
            Slider(value: $draftVolume, in: 0...100) { editing in
                editingVolume = editing
                if !editing { service.setVolume(Int(draftVolume.rounded())) }
            }
            .controlSize(.mini)
            .frame(width: 90)
        }
    }

    private func controlButton(_ name: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size))
                .foregroundColor(.white)
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleButton(_ name: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(active ? Color.green : Color.white.opacity(0.4))
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let image = service.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "music.note")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
}

/// Barra de progreso arrastrable. `scrub` vale la fracción mientras se arrastra; `onCommit` al soltar.
private struct ScrubBar: View {
    let fraction: Double
    let enabled: Bool
    @Binding var scrub: Double?
    let onCommit: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let value = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.white)
                    .frame(width: width * value, height: 4)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard enabled else { return }
                        scrub = min(max(drag.location.x / width, 0), 1)
                    }
                    .onEnded { drag in
                        guard enabled else { return }
                        let final = min(max(drag.location.x / width, 0), 1)
                        scrub = nil
                        onCommit(final)
                    }
            )
        }
        .frame(height: 14)
    }
}
