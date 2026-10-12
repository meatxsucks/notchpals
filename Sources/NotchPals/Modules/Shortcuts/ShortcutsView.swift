import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ShortcutsViewModel: ObservableObject {
    @Published private(set) var apps: [FavoriteApp] = []
    @Published private(set) var shortcuts: [String] = []
    @Published private(set) var runningShortcut: String?
    @Published private(set) var lastRan: String?
    @Published var errorMessage: String?
    @Published private(set) var isLoadingList = false

    private let store = FavoriteAppsStore()
    private var list = FavoriteAppList()

    init() {
        list = store.load()
        refreshApps()
    }

    // MARK: Apps

    static func appURL(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    func refreshApps() {
        apps = list.filtered { Self.appURL(for: $0) != nil }
    }

    func launch(_ app: FavoriteApp) {
        guard let url = Self.appURL(for: app.bundleID) else {
            errorMessage = "\(app.name) no está instalada"
            refreshApps()
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, error in
            if let error {
                let text = error.localizedDescription
                Task { @MainActor in self?.errorMessage = text }
            }
        }
    }

    func icon(for app: FavoriteApp) -> NSImage? {
        guard let url = Self.appURL(for: app.bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func remove(_ app: FavoriteApp) {
        list.remove(bundleID: app.bundleID)
        store.save(list)
        refreshApps()
    }

    func addAppFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        list.add(FavoriteApp(bundleID: bundleID, name: name))
        store.save(list)
        refreshApps()
    }

    // MARK: Atajos de Apple

    func loadShortcuts() {
        guard !isLoadingList else { return }
        isLoadingList = true
        Task {
            do {
                let names = try await ShortcutsRunner.list()
                shortcuts = names
                if errorMessage != nil, names.isEmpty == false { errorMessage = nil }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingList = false
        }
    }

    func run(_ name: String) {
        guard runningShortcut == nil else { return }
        runningShortcut = name
        errorMessage = nil
        lastRan = nil
        Task {
            do {
                try await ShortcutsRunner.runShortcut(named: name)
                lastRan = name
            } catch {
                errorMessage = "\(name): \(error.localizedDescription)"
            }
            runningShortcut = nil
        }
    }
}

struct ShortcutsView: View {
    @StateObject private var model = ShortcutsViewModel()

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                appsGrid
                Divider().overlay(Color.white.opacity(0.15))
                shortcutsList
            }
            statusBar
        }
        .padding(12)
        .frame(width: 600, height: 150)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear { model.loadShortcuts() }
    }

    private var appsGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(46), spacing: 6), count: 4)
        return ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(model.apps) { app in
                    Button { model.launch(app) } label: {
                        VStack(spacing: 2) {
                            if let icon = model.icon(for: app) {
                                Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                            } else {
                                Image(systemName: "app").frame(width: 28, height: 28)
                            }
                            Text(app.name)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 46)
                    }
                    .buttonStyle(.plain)
                    .help(app.name)
                    .contextMenu {
                        Button("Quitar de favoritos") { model.remove(app) }
                    }
                }
                Button { model.addAppFromPanel() } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "plus.circle").font(.system(size: 20))
                            .frame(width: 28, height: 28)
                        Text("Añadir").font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 46)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 214)
    }

    private var shortcutsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Atajos de Apple", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button { model.loadShortcuts() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
                .disabled(model.isLoadingList)
            }
            if model.shortcuts.isEmpty {
                Text(model.isLoadingList ? "Cargando…" : "Sin atajos")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(model.shortcuts, id: \.self) { name in
                            Button { model.run(name) } label: {
                                HStack(spacing: 6) {
                                    if model.runningShortcut == name {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Image(systemName: "play.fill").font(.system(size: 8))
                                    }
                                    Text(name).font(.system(size: 11)).lineLimit(1)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .disabled(model.runningShortcut != nil)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var statusBar: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.red.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let running = model.runningShortcut {
            Text("Ejecutando \(running)…")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let done = model.lastRan {
            Label("\(done) completado", systemImage: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.green.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
