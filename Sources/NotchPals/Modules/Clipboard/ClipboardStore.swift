import AppKit
import SwiftUI

@MainActor
final class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    static let ignoredTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
    ]

    @Published private(set) var history = ClipboardHistory()

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    private init() {
        lastChangeCount = pasteboard.changeCount
    }

    var items: [ClipboardItem] { history.displayItems }

    /// Inicia el polling; es idempotente.
    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        let types = (pasteboard.types ?? []).map { $0.rawValue }
        if types.contains(where: { Self.ignoredTypes.contains($0) }) { return }
        guard let text = pasteboard.string(forType: .string) else { return }
        history.add(text)
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        // Evita que el polling lo registre de nuevo.
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ item: ClipboardItem) { history.togglePin(id: item.id) }
    func remove(_ item: ClipboardItem) { history.remove(id: item.id) }
    func clearUnpinned() { history.clearUnpinned() }
}
