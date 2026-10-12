import Foundation

/// Cola FIFO pura (sin red ni AppKit) de solicitudes de aprobación pendientes.
/// Máximo `capacity`; lo que llegue de más no entra y debe resolverse como `.ask`.
struct ApprovalQueue {
    struct Entry: Identifiable, Equatable {
        let request: ApprovalRequest
        let enqueuedAt: Date
        var id: UUID { request.id }
    }

    enum EnqueueResult: Equatable {
        /// Entró a la cola; `position` es 1-based.
        case queued(position: Int)
        /// Cola llena: el llamador debe responder `.ask` de inmediato.
        case overflow(ApprovalDecision)
    }

    static let defaultCapacity = 5

    let capacity: Int
    private(set) var entries: [Entry] = []

    init(capacity: Int = ApprovalQueue.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }
    var isFull: Bool { entries.count >= capacity }
    var first: Entry? { entries.first }

    func contains(_ id: UUID) -> Bool { entries.contains { $0.id == id } }

    mutating func enqueue(_ request: ApprovalRequest, now: Date = Date()) -> EnqueueResult {
        guard !isFull else { return .overflow(.ask) }
        entries.append(Entry(request: request, enqueuedAt: now))
        return .queued(position: entries.count)
    }

    /// Quita y devuelve la solicitud con ese id (nil si ya no está).
    @discardableResult
    mutating func resolve(_ id: UUID) -> Entry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return entries.remove(at: index)
    }

    /// Quita y devuelve las solicitudes con al menos `timeout` segundos de espera.
    @discardableResult
    mutating func expire(now: Date = Date(), timeout: TimeInterval) -> [Entry] {
        let expired = entries.filter { now.timeIntervalSince($0.enqueuedAt) >= timeout }
        guard !expired.isEmpty else { return [] }
        entries.removeAll { entry in now.timeIntervalSince(entry.enqueuedAt) >= timeout }
        return expired
    }

    @discardableResult
    mutating func clear() -> [Entry] {
        let all = entries
        entries.removeAll()
        return all
    }
}
