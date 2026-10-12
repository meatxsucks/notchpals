import AppKit
import Foundation

/// Backend de un reproductor. Protocolo para poder simularlo en tests.
@MainActor
protocol MusicBackend: AnyObject {
    var app: MusicApp { get }
    func isRunning() -> Bool
    func fetchSnapshot() throws -> MusicSnapshot
    func artwork(for track: MusicTrack) async -> NSImage?
    func send(_ command: MusicCommand) throws
    /// Controles soportados (por defecto según la app).
    var capabilities: MusicCapabilities { get }
}

extension MusicBackend {
    var capabilities: MusicCapabilities { MusicCapabilities(app: app) }
}

/// Ejecuta AppleScript. Abstracción para tests.
@MainActor
protocol AppleScriptRunning {
    func run(_ source: String, app: MusicApp) throws -> NSAppleEventDescriptor
}

@MainActor
struct AppleScriptRunner: AppleScriptRunning {
    func run(_ source: String, app: MusicApp) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw MusicError.scriptFailed("script inválido")
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let info = errorInfo {
            let code = (info["NSAppleScriptErrorNumber"] as? NSNumber)?.intValue ?? 0
            let message = (info["NSAppleScriptErrorMessage"] as? String) ?? "error \(code)"
            throw MusicError.from(code: code, message: message, app: app)
        }
        return result
    }
}

/// Backend basado en AppleScript para Spotify y Apple Music.
@MainActor
final class ScriptedMusicBackend: MusicBackend {
    let app: MusicApp
    private let runner: AppleScriptRunning
    private let runningCheck: () -> Bool

    init(app: MusicApp,
         runner: AppleScriptRunning = AppleScriptRunner(),
         runningCheck: (() -> Bool)? = nil) {
        self.app = app
        self.runner = runner
        let bundleID = app.bundleID
        self.runningCheck = runningCheck ?? {
            NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
        }
    }

    func isRunning() -> Bool { runningCheck() }

    func fetchSnapshot() throws -> MusicSnapshot {
        guard isRunning() else { throw MusicError.notRunning(app) }
        let descriptor = try runner.run(Self.fetchScript(for: app), app: app)
        guard let text = descriptor.stringValue,
              let snapshot = MusicParser.parse(text, app: app) else {
            throw MusicError.badOutput
        }
        return snapshot
    }

    func send(_ command: MusicCommand) throws {
        guard isRunning() else { throw MusicError.notRunning(app) }
        _ = try runner.run(Self.commandScript(command, for: app), app: app)
    }

    /// Script de una orden (puro, testeable).
    static func commandScript(_ command: MusicCommand, for app: MusicApp) -> String {
        let verb: String
        switch command {
        case .playPause: verb = "playpause"
        case .previous: verb = "previous track"
        case .next: verb = "next track"
        case .seek(let t): verb = String(format: "set player position to %.2f", max(0, t))
        case .setVolume(let v): verb = "set sound volume to \(min(100, max(0, v)))"
        case .setShuffle(let on):
            verb = "set \(app == .spotify ? "shuffling" : "shuffle enabled") to \(on ? "true" : "false")"
        case .setRepeat(let mode):
            switch app {
            case .spotify: verb = "set repeating to \(mode == .off ? "false" : "true")"
            case .appleMusic: verb = "set song repeat to \(mode.rawValue)"
            }
        }
        return "tell application \"\(app.scriptName)\" to \(verb)"
    }

    func artwork(for track: MusicTrack) async -> NSImage? {
        switch app {
        case .spotify:
            guard let url = track.artworkURL else { return nil }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return NSImage(data: data)
            } catch {
                return nil
            }
        case .appleMusic:
            // Mejor esfuerzo: los datos crudos de la carátula pueden no ser decodificables.
            let source = """
            tell application "Music"
                try
                    return data of artwork 1 of current track
                on error
                    return ""
                end try
            end tell
            """
            guard isRunning(),
                  let descriptor = try? runner.run(source, app: app) else { return nil }
            let data = descriptor.data
            guard !data.isEmpty else { return nil }
            return NSImage(data: data)
        }
    }

    // MARK: - Scripts

    static func fetchScript(for app: MusicApp) -> String {
        let isSpotify = app == .spotify
        let artworkLine = isSpotify ? "set art to artwork url of t" : "set art to \"\""
        let durationExpr = isSpotify ? "(duration of t) / 1000" : "duration of t"
        let shuffleProp = isSpotify ? "shuffling" : "shuffle enabled"
        let repeatProp = isSpotify ? "repeating" : "song repeat"
        return """
        tell application "\(app.scriptName)"
            set d to character id 31
            set st to player state as text
            if st is "stopped" then return st
            set t to current track
            set art to ""
            try
                \(artworkLine)
            end try
            set pos to ""
            try
                set pos to (player position) as text
            end try
            set dur to ""
            try
                set dur to (\(durationExpr)) as text
            end try
            set vol to ""
            try
                set vol to (sound volume) as text
            end try
            set shuf to ""
            try
                set shuf to (\(shuffleProp)) as text
            end try
            set rep to ""
            try
                set rep to (\(repeatProp)) as text
            end try
            return st & d & (name of t) & d & (artist of t) & d & (album of t) & d & art & d & pos & d & dur & d & vol & d & shuf & d & rep
        end tell
        """
    }
}
