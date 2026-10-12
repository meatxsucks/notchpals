import AppKit
import SwiftUI

@MainActor
struct MusicView: View {
    @StateObject private var service = MusicService()

    var body: some View {
        HStack(spacing: 14) {
            artworkView
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let track = service.snapshot?.track {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.snapshot?.app.displayName.uppercased() ?? "")
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
                    Spacer(minLength: 4)
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
        .onAppear { service.start() }
        .onDisappear { service.stop() }
    }

    private var emptyTitle: String {
        service.snapshot == nil ? "Música" : "Nada en reproducción"
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

    private var controls: some View {
        HStack(spacing: 22) {
            controlButton("backward.fill", size: 16) { service.perform(.previous) }
            controlButton(service.snapshot?.state == .playing ? "pause.fill" : "play.fill", size: 22) {
                service.perform(.playPause)
            }
            controlButton("forward.fill", size: 16) { service.perform(.next) }
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
}
