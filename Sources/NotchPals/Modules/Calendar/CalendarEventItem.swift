import Foundation

/// Valor plano de un evento (independiente de EventKit para poder testearlo).
struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    /// Color del calendario en sRGB (0...1).
    let red: Double
    let green: Double
    let blue: Double

    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
         red: Double = 0.4, green: Double = 0.6, blue: Double = 1.0) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.red = red
        self.green = green
        self.blue = blue
    }

    func isInProgress(at now: Date) -> Bool {
        start <= now && now < end
    }
}

enum CalendarEventFilter {
    /// Descarta eventos ya terminados, ordena (en curso primero, luego por inicio) y limita.
    /// Los eventos de día completo van después de los con hora del mismo día.
    static func upcoming(_ items: [CalendarEventItem],
                         now: Date,
                         limit: Int = 5,
                         calendar: Calendar = .current) -> [CalendarEventItem] {
        guard limit > 0 else { return [] }
        let alive = items.filter { $0.end > now }
        let sorted = alive.sorted { a, b in
            let aLive = a.isInProgress(at: now) && !a.isAllDay
            let bLive = b.isInProgress(at: now) && !b.isAllDay
            if aLive != bLive { return aLive }
            let aDay = calendar.startOfDay(for: a.start)
            let bDay = calendar.startOfDay(for: b.start)
            if aDay != bDay { return aDay < bDay }
            if a.isAllDay != b.isAllDay { return !a.isAllDay }
            if a.start != b.start { return a.start < b.start }
            if a.end != b.end { return a.end < b.end }
            return a.title < b.title
        }
        return Array(sorted.prefix(limit))
    }
}
