import Foundation

/// Instala o quita el hook con copia de seguridad, vista previa y confirmación explícita.
@MainActor
final class HookInstallModel: ObservableObject {
    static let shared = HookInstallModel()

    enum Action { case install, remove }

    @Published private(set) var isInstalled = false
    @Published private(set) var preview: [String]?
    @Published private(set) var pendingAction: Action?
    @Published var message: String?

    private let fileManager = FileManager.default
    private var pendingText: String?
    private var home: URL { fileManager.homeDirectoryForCurrentUser }
    private var settingsURL: URL { home.appendingPathComponent(".claude/settings.json") }
    private var scriptURL: URL { home.appendingPathComponent(".notchpals/hook.sh") }
    private var command: String { scriptURL.path }

    init() { refresh() }

    func refresh() {
        let settings = try? HookInstaller.parse(try? Data(contentsOf: settingsURL))
        isInstalled = settings.map { HookInstaller.isInstalled($0, command: command) } ?? false
    }

    func prepare(_ action: Action) {
        message = nil
        do {
            let current = try HookInstaller.parse(try? Data(contentsOf: settingsURL))
            let updated = action == .install
                ? try HookInstaller.installing(into: current, command: command)
                : HookInstaller.removing(from: current, command: command)
            let newText = HookInstaller.render(updated)
            let lines = HookInstaller.diff(old: HookInstaller.render(current), new: newText)
            guard !lines.isEmpty else { message = "No hay cambios que aplicar."; return }
            pendingText = newText
            pendingAction = action
            preview = lines
        } catch {
            message = error.localizedDescription
        }
    }

    func cancel() { preview = nil; pendingAction = nil; pendingText = nil }

    /// Solo se llama tras el clic en «Confirmar».
    func confirm() {
        guard let text = pendingText, let action = pendingAction else { return }
        do {
            try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: settingsURL.path) {
                let stamp = Self.stamp.string(from: Date())
                let backup = settingsURL.deletingLastPathComponent()
                    .appendingPathComponent("settings.json.notchpals-backup-\(stamp)")
                try fileManager.copyItem(at: settingsURL, to: backup)
            }
            if action == .install { try writeScript() }
            try text.write(to: settingsURL, atomically: true, encoding: .utf8)
            message = action == .install ? "Hook instalado. Copia de seguridad creada." : "Hook quitado. Copia de seguridad creada."
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
        cancel()
        refresh()
    }

    private func writeScript() throws {
        try fileManager.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        let source = HookInstaller.scriptSource
            .components(separatedBy: "\n").map { $0.hasPrefix("    ") ? String($0.dropFirst(4)) : $0 }
            .joined(separator: "\n") + "\n"
        try source.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
