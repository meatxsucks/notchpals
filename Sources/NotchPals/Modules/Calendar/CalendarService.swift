import Foundation
import EventKit
import AppKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    enum Access: Equatable {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var events: [CalendarEventItem] = []
    @Published private(set) var now: Date = Date()

    private let store = EKEventStore()
    private var cancellable: AnyCancellable?
    private var started = false

    init() {
        cancellable = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: store)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.reload() }
            }
    }

    /// Idempotente: comprueba/solicita permiso y carga eventos.
    func start() async {
        refreshAccessFromStatus()
        if !started {
            started = true
            if currentStatusIsNotDetermined() {
                let granted = await requestAccess()
                access = granted ? .granted : .denied
            }
        }
        reload()
    }

    func reload() {
        now = Date()
        refreshAccessFromStatus()
        guard access == .granted else {
            events = []
            return
        }
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 7, to: startOfToday) else { return }
        let predicate = store.predicateForEvents(withStart: startOfToday, end: end, calendars: nil)
        let items = store.events(matching: predicate).map(Self.makeItem)
        events = CalendarEventFilter.upcoming(items, now: now, limit: 5, calendar: cal)
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private func currentStatusIsNotDetermined() -> Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
    }

    private func refreshAccessFromStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess: access = .granted
            case .notDetermined: access = .unknown
            default: access = .denied
            }
        } else {
            switch status {
            case .authorized: access = .granted
            case .notDetermined: access = .unknown
            default: access = .denied
            }
        }
    }

    private func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                store.requestAccess(to: .event) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    private static func makeItem(_ event: EKEvent) -> CalendarEventItem {
        var r = 0.4, g = 0.6, b = 1.0
        if let cg = event.calendar?.cgColor,
           let ns = NSColor(cgColor: cg)?.usingColorSpace(.sRGB) {
            r = Double(ns.redComponent)
            g = Double(ns.greenComponent)
            b = Double(ns.blueComponent)
        }
        let start = event.startDate ?? Date()
        let end = event.endDate ?? start
        let baseID = event.eventIdentifier ?? UUID().uuidString
        let title = (event.title?.isEmpty == false) ? event.title! : "Sin título"
        return CalendarEventItem(id: "\(baseID)-\(start.timeIntervalSince1970)",
                                 title: title, start: start, end: end,
                                 isAllDay: event.isAllDay, red: r, green: g, blue: b)
    }
}
