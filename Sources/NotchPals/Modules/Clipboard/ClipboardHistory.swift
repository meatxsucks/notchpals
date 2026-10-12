import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    var isPinned: Bool
    let date: Date

    init(id: UUID = UUID(), text: String, isPinned: Bool = false, date: Date = Date()) {
        self.id = id
        self.text = text
        self.isPinned = isPinned
        self.date = date
    }
}

/// Lógica pura del historial (sin NSPasteboard). `items` está en orden de recencia (más nuevo primero).
struct ClipboardHistory: Equatable {
    static let defaultLimit = 20

    private(set) var items: [ClipboardItem] = []
    let limit: Int

    init(limit: Int = ClipboardHistory.defaultLimit) {
        self.limit = max(1, limit)
    }

    /// Ítems para mostrar: anclados primero, luego el resto; cada grupo por recencia.
    var displayItems: [ClipboardItem] {
        items.filter { $0.isPinned } + items.filter { !$0.isPinned }
    }

    /// Inserta texto al inicio. Devuelve false si se ignoró (vacío o duplicado consecutivo).
    @discardableResult
    mutating func add(_ text: String, date: Date = Date()) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if let first = items.first, first.text == text { return false }
        items.insert(ClipboardItem(text: text, date: date), at: 0)
        trim()
        return true
    }

    mutating func togglePin(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isPinned.toggle()
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Quita los no anclados.
    mutating func clearUnpinned() {
        items.removeAll { !$0.isPinned }
    }

    /// Elimina los no anclados más antiguos hasta respetar el límite.
    private mutating func trim() {
        while items.count > limit {
            guard let idx = items.lastIndex(where: { !$0.isPinned }) else { break }
            items.remove(at: idx)
        }
    }
}
