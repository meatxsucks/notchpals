import Foundation

/// Reproductores soportados.
enum MusicApp: String, CaseIterable, Equatable {
    case spotify
    case appleMusic

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }

    var bundleID: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .appleMusic: return "com.apple.Music"
        }
    }

    /// Nombre de la app para `tell application "..."`.
    var scriptName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Music"
        }
    }
}

enum PlaybackState: String, Equatable {
    case playing
    case paused
    case stopped

    init(raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "playing": self = .playing
        case "paused": self = .paused
        default: self = .stopped
        }
    }
}

enum MusicCommand: Equatable {
    case playPause
    case previous
    case next
}

struct MusicTrack: Equatable {
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?

    /// Identidad simple para saber cuándo cambió la pista.
    var id: String { "\(title)|\(artist)|\(album)" }
}

struct MusicSnapshot: Equatable {
    var app: MusicApp
    var state: PlaybackState
    var track: MusicTrack?
}

enum MusicError: Error, Equatable {
    case notRunning(MusicApp)
    case permissionDenied(MusicApp)
    case scriptFailed(String)
    case badOutput

    var userMessage: String {
        switch self {
        case .notRunning(let app):
            return "\(app.displayName) no está abierto."
        case .permissionDenied(let app):
            return "Sin permiso para controlar \(app.displayName). Actívalo en Ajustes del Sistema > Privacidad y seguridad > Automatización."
        case .scriptFailed(let detail):
            return "No se pudo leer la música: \(detail)"
        case .badOutput:
            return "Respuesta inesperada del reproductor."
        }
    }

    /// Traduce un código de error de AppleScript.
    static func from(code: Int, message: String, app: MusicApp) -> MusicError {
        switch code {
        case -1743, -1744: return .permissionDenied(app)   // no autorizado / requiere consentimiento
        case -600, -609: return .notRunning(app)            // app no ejecutándose / conexión inválida
        default: return .scriptFailed(message)
        }
    }
}

enum MusicParser {
    /// Separador de campos (ASCII 31, "unit separator").
    static let separator: Character = "\u{1F}"

    /// Formato: `estado` o `estado SEP título SEP artista SEP álbum [SEP urlCarátula]`.
    static func parse(_ output: String, app: MusicApp) -> MusicSnapshot? {
        let parts = output
            .split(separator: separator, omittingEmptySubsequences: false)
            .map { String($0) }
        guard let first = parts.first, !first.isEmpty else { return nil }
        let state = PlaybackState(raw: first)
        if state == .stopped || parts.count < 3 {
            return state == .stopped
                ? MusicSnapshot(app: app, state: .stopped, track: nil)
                : nil
        }
        let album = parts.count > 3 ? parts[3] : ""
        var url: URL?
        if parts.count > 4 {
            let raw = parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty { url = URL(string: raw) }
        }
        let track = MusicTrack(title: parts[1], artist: parts[2], album: album, artworkURL: url)
        return MusicSnapshot(app: app, state: state, track: track)
    }
}

enum MusicPlayerChooser {
    /// Prefiere el que está sonando; luego el que tenga pista; luego el primero.
    static func choose(_ snapshots: [MusicSnapshot]) -> MusicSnapshot? {
        if let s = snapshots.first(where: { $0.state == .playing }) { return s }
        if let s = snapshots.first(where: { $0.track != nil }) { return s }
        return snapshots.first
    }
}
