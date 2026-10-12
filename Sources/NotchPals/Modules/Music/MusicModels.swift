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

/// Modo de repetición. Spotify solo distingue off/all; Apple Music también `one`.
enum RepeatMode: String, Equatable, CaseIterable {
    case off
    case one
    case all

    /// Interpreta la salida de AppleScript ("off"/"one"/"all" o booleano de Spotify).
    init?(raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "off", "false": self = .off
        case "one": self = .one
        case "all", "true", "on": self = .all
        default: return nil
        }
    }

    /// Siguiente modo dentro de los soportados (cicla). Si el actual no está, devuelve el primero.
    func next(in supported: [RepeatMode]) -> RepeatMode {
        guard !supported.isEmpty else { return self }
        guard let idx = supported.firstIndex(of: self) else { return supported[0] }
        return supported[(idx + 1) % supported.count]
    }
}

enum MusicCommand: Equatable {
    case playPause
    case previous
    case next
    /// Salta a una posición (segundos).
    case seek(TimeInterval)
    /// Volumen 0...100.
    case setVolume(Int)
    case setShuffle(Bool)
    case setRepeat(RepeatMode)
}

/// Qué controles soporta un reproductor (la vista oculta lo no soportado).
struct MusicCapabilities: Equatable {
    var seek: Bool
    var volume: Bool
    var shuffle: Bool
    var repeatModes: [RepeatMode]

    init(seek: Bool = true, volume: Bool = true, shuffle: Bool = true, repeatModes: [RepeatMode] = RepeatMode.allCases) {
        self.seek = seek
        self.volume = volume
        self.shuffle = shuffle
        self.repeatModes = repeatModes
    }

    init(app: MusicApp) {
        switch app {
        case .spotify: self.init(repeatModes: [.off, .all])
        case .appleMusic: self.init(repeatModes: [.off, .one, .all])
        }
    }

    var supportsRepeat: Bool { !repeatModes.isEmpty }
}

/// Cálculo puro de progreso de la pista.
enum MusicProgress {
    /// Posición estimada: `base` + tiempo transcurrido desde el sondeo si está sonando, acotada a la duración.
    static func position(base: TimeInterval, duration: TimeInterval, isPlaying: Bool, elapsed: TimeInterval) -> TimeInterval {
        let b = base.isFinite ? max(0, base) : 0
        let e = (isPlaying && elapsed.isFinite) ? max(0, elapsed) : 0
        let p = b + e
        return duration > 0 ? min(p, duration) : p
    }

    /// Fracción 0...1 (0 si la duración es desconocida).
    static func fraction(position: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0, position.isFinite else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    /// `m:ss` o `h:mm:ss`.
    static func format(_ time: TimeInterval) -> String {
        let total = time.isFinite ? Int(max(0, time)) : 0
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
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
    /// Posición actual en segundos (al momento del sondeo).
    var position: TimeInterval = 0
    /// Duración en segundos; 0 si se desconoce.
    var duration: TimeInterval = 0
    /// Volumen 0...100, `nil` si no se pudo leer.
    var volume: Int?
    var shuffle: Bool?
    var repeatMode: RepeatMode?
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

    /// Formato: `estado` o
    /// `estado SEP título SEP artista SEP álbum [SEP urlCarátula [SEP posición(s) SEP duración(s) SEP volumen SEP shuffle SEP repeat]]`.
    /// Los campos extra son opcionales y pueden venir vacíos.
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
        return MusicSnapshot(
            app: app,
            state: state,
            track: track,
            position: seconds(field(parts, 5)) ?? 0,
            duration: seconds(field(parts, 6)) ?? 0,
            volume: volume(field(parts, 7)),
            shuffle: bool(field(parts, 8)),
            repeatMode: RepeatMode(raw: field(parts, 9))
        )
    }

    private static func field(_ parts: [String], _ index: Int) -> String {
        index < parts.count ? parts[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    /// Acepta coma decimal (algunos locales) y notación científica.
    static func seconds(_ raw: String) -> TimeInterval? {
        let text = raw.replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty, let value = Double(text), value.isFinite else { return nil }
        return max(0, value)
    }

    static func volume(_ raw: String) -> Int? {
        guard let value = seconds(raw) else { return nil }
        return min(100, max(0, Int(value.rounded())))
    }

    static func bool(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
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
