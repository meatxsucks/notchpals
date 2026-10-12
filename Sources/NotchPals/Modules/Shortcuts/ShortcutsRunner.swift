import Foundation

struct ShortcutsCommandResult: Equatable {
    var status: Int32
    var stdout: String
    var stderr: String
}

enum ShortcutsError: LocalizedError, Equatable {
    case launchFailed(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let m): return "No se pudo ejecutar shortcuts: \(m)"
        case .failed(let m): return m
        }
    }
}

/// Ejecuta `/usr/bin/shortcuts` fuera del hilo principal.
enum ShortcutsRunner {
    static let executablePath = "/usr/bin/shortcuts"

    static func list() async throws -> [String] {
        let r = try await run(["list"])
        guard r.status == 0 else { throw ShortcutsError.failed(message(for: r)) }
        return ShortcutsListParser.parse(r.stdout)
    }

    static func runShortcut(named name: String) async throws {
        let r = try await run(["run", name])
        guard r.status == 0 else { throw ShortcutsError.failed(message(for: r)) }
    }

    private static func message(for r: ShortcutsCommandResult) -> String {
        let text = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "shortcuts terminó con código \(r.status)" : text
    }

    private static func run(_ arguments: [String]) async throws -> ShortcutsCommandResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            let out = Pipe()
            let err = Pipe()
            process.standardOutput = out
            process.standardError = err
            process.standardInput = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                throw ShortcutsError.launchFailed(error.localizedDescription)
            }
            // Leer stderr en paralelo para no provocar deadlock si algún pipe se llena.
            var errData = Data()
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().async {
                errData = err.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            let outData = out.fileHandleForReading.readDataToEndOfFile()
            group.wait()
            process.waitUntilExit()
            return ShortcutsCommandResult(
                status: process.terminationStatus,
                stdout: String(decoding: outData, as: UTF8.self),
                stderr: String(decoding: errData, as: UTF8.self)
            )
        }.value
    }
}
