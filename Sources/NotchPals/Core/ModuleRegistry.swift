/// Lista ordenada de módulos. Cada tipo lo implementa su agente en Modules/<Nombre>/.
enum ModuleRegistry {
    static var all: [NotchModule] {
        [
            MusicModule(),
            CalendarModule(),
            ClipboardModule(),
            ShelfModule(),
            ShortcutsModule(),
        ]
    }
}
