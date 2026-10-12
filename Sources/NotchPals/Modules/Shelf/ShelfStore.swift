import Foundation
import Combine

/// Un archivo guardado en la bandeja (copia dentro de la carpeta temporal).
struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var name: String { url.lastPathComponent }
}

/// Lógica de almacenamiento de la bandeja, sin dependencias de UI. El directorio es inyectable.
final class ShelfStorage {
    let directory: URL
    private let fm: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.directory = directory
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("NotchPalsShelf", isDirectory: true)
        self.fm = fileManager
    }

    /// Copia `source` a la bandeja con un nombre único y devuelve la URL de la copia.
    func add(_ source: URL) throws -> URL {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let dest = uniqueDestination(for: source.lastPathComponent)
        try fm.copyItem(at: source, to: dest)
        return dest
    }

    /// Borra una copia de la bandeja.
    func remove(_ url: URL) {
        try? fm.removeItem(at: url)
    }

    /// Borra toda la carpeta temporal.
    func clear() {
        try? fm.removeItem(at: directory)
    }

    /// "foo.txt" -> "foo 2.txt", "foo 3.txt", ... si ya existe.
    func uniqueDestination(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = directory.appendingPathComponent(name)
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            n += 1
        }
        return candidate
    }
}

/// Estado observable de la bandeja para la vista.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    private let storage: ShelfStorage

    init(storage: ShelfStorage = ShelfStorage()) {
        self.storage = storage
        // Arranque limpio: restos de sesiones anteriores no se muestran.
        storage.clear()
    }

    func add(urls: [URL]) {
        for url in urls where url.isFileURL {
            if let copy = try? storage.add(url) {
                items.append(ShelfItem(id: UUID(), url: copy))
            }
        }
    }

    func remove(_ item: ShelfItem) {
        storage.remove(item.url)
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        storage.clear()
        items.removeAll()
    }
}
