import SwiftUI

struct CalendarModule: NotchModule {
    let id = "calendar"
    let title = "Calendario"
    let systemImage = "calendar"

    @MainActor func makeView() -> AnyView {
        AnyView(CalendarModuleView())
    }
}

private struct CalendarModuleView: View {
    @StateObject private var service = CalendarService()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
            .task { await service.start() }
            .onReceive(ticker) { _ in service.reload() }
    }

    @ViewBuilder private var content: some View {
        switch service.access {
        case .denied:
            stateView(icon: "lock.fill", text: "Sin acceso al calendario") {
                Button("Abrir Ajustes del Sistema") { service.openSystemSettings() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        case .unknown:
            stateView(icon: "calendar", text: "Solicitando acceso…") { EmptyView() }
        case .granted:
            if service.events.isEmpty {
                stateView(icon: "calendar.badge.checkmark", text: "Sin eventos próximos") { EmptyView() }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(service.events) { event in
                        row(event)
                    }
                }
            }
        }
    }

    private func stateView<A: View>(icon: String, text: String,
                                    @ViewBuilder action: () -> A) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(.secondary)
            Text(text).font(.system(size: 12)).foregroundColor(.secondary)
            action()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ event: CalendarEventItem) -> some View {
        let live = event.isInProgress(at: service.now) && !event.isAllDay
        return HStack(spacing: 8) {
            Circle()
                .fill(Color(.sRGB, red: event.red, green: event.green, blue: event.blue, opacity: 1))
                .frame(width: 8, height: 8)
            Text(timeText(event))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundColor(live ? .white : .secondary)
                .frame(width: 92, alignment: .leading)
            Text(event.title)
                .font(.system(size: 12, weight: live ? .semibold : .regular))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
            if live {
                Text("AHORA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.green))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill(live ? Color.white.opacity(0.14) : Color.clear))
    }

    private func timeText(_ event: CalendarEventItem) -> String {
        if event.isAllDay { return "Todo el día" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        var text = "\(f.string(from: event.start))–\(f.string(from: event.end))"
        if !Calendar.current.isDate(event.start, inSameDayAs: service.now) {
            let d = DateFormatter()
            d.dateFormat = "EEE"
            text = "\(d.string(from: event.start)) \(f.string(from: event.start))"
        }
        return text
    }
}
