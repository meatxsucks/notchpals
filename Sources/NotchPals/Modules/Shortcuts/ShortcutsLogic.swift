import Foundation

/// App favorita, identificada por su bundle id. Codificable para persistirla.
struct FavoriteApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

/// Lista de favoritos (lógica pura, sin AppKit).
struct FavoriteAppList: Equatable {
    private(set) var items: [FavoriteApp]

    init(items: [FavoriteApp] = FavoriteAppList.defaultItems) {
        self.items = items
    }

    static let defaultItems: [FavoriteApp] = [
        FavoriteApp(bundleID: "com.apple.Safari", name: "Safari"),
        FavoriteApp(bundleID: "com.apple.Notes", name: "Notas"),
        FavoriteApp(bundleID: "com.apple.Terminal", name: "Terminal"),
        FavoriteApp(bundleID: "com.apple.finder", name: "Finder"),
        FavoriteApp(bundleID: "com.apple.systempreferences", name: "Ajustes del Sistema"),
    ]

    /// Agrega si no existe (por bundle id). Devuelve true si se agregó.
    @discardableResult
    mutating func add(_ app: FavoriteApp) -> Bool {
        guard !items.contains(where: { $0.bundleID == app.bundleID }) else { return false }
        items.append(app)
        return true
    }

    mutating func remove(bundleID: String) {
        items.removeAll { $0.bundleID == bundleID }
    }

    /// Mantiene solo los favoritos que `isInstalled` acepta (omite apps no instaladas).
    func filtered(isInstalled: (String) -> Bool) -> [FavoriteApp] {
        items.filter { isInstalled($0.bundleID) }
    }
}

/// Persistencia de la lista en UserDefaults (JSON).
struct FavoriteAppsStore {
    static let defaultsKey = "notchpals.shortcuts.favoriteApps"

    let defaults: UserDefaults
    let key: String

    init(defaults: UserDefaults = .standard, key: String = FavoriteAppsStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> FavoriteAppList {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([FavoriteApp].self, from: data)
        else { return FavoriteAppList() }
        return FavoriteAppList(items: items)
    }

    func save(_ list: FavoriteAppList) {
        guard let data = try? JSONEncoder().encode(list.items) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Parseo de la salida de `shortcuts list` (un nombre por línea).
enum ShortcutsListParser {
    static func parse(_ output: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for line in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let name = line.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            result.append(name)
        }
        return result
    }
}
