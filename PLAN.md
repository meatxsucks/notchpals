# NotchPals — plan

App nativa de macOS 13+ (SwiftUI + AppKit, Swift Package) que convierte el notch en un panel
de herramientas. Vive en la barra de menú, sin ícono en el Dock; el panel se expande al pasar el mouse.

## Arquitectura
- `Core/`: panel flotante (`NotchPanelController`), geometría del notch, vista raíz, `NotchViewModel`.
- `Modules/<Nombre>/`: cada herramienta implementa el protocolo `NotchModule` y se lista en `ModuleRegistry`.
- Regla: un módulo solo toca su carpeta (y su test). Cambios al Core se acuerdan primero.

## Módulos (un agente cada uno)
| Módulo | Tipo | Integración |
|---|---|---|
| Music | `MusicModule` | Spotify y Apple Music vía ScriptingBridge/AppleScript: carátula, título, play/pausa/siguiente |
| Calendar | `CalendarModule` | EventKit: próximos eventos de hoy |
| Clipboard | `ClipboardModule` | Historial de `NSPasteboard` (polling por changeCount), click para recopiar |
| Shelf | `ShelfModule` | Bandeja temporal: arrastrar archivos adentro y afuera |
| Shortcuts | `ShortcutsModule` | Lanzar apps y atajos de Atajos de Apple (`shortcuts run`) |

## Fases
1. Esqueleto + Core (hecho)
2. Módulos en paralelo
3. Integración, permisos (Info.plist / entitlements), pulido visual
4. Ajustes (qué módulos mostrar, orden), empaquetado .app

## Limitación
Desarrollado desde Linux: no se puede compilar ni probar aquí. Hay que abrir `Package.swift` en Xcode.

## Módulo Claude
- **Chat:** Messages API por HTTP (`claude-opus-5-5`, effort `low`). La API key vive en el llavero de macOS.
- **Aprobaciones:** servidor local en `127.0.0.1:47600` (solo loopback, con token en `~/.notchpals/token`).
  Un hook `PermissionRequest` de Claude Code (solo se dispara cuando Claude Code va a preguntar) ejecuta `scripts/claude-approve-hook.sh`, que consulta al notch y devuelve
  Permitir / Siempre / Rechazar. Sin respuesta en 100 s (o si la app está cerrada) no imprime nada y Claude Code pregunta en la terminal.
- Configuración en `~/.claude/settings.json`:
  `{"hooks":{"PermissionRequest":[{"hooks":[{"type":"command","command":"/ruta/a/notchpals/scripts/claude-approve-hook.sh","timeout":120}]}]}}`
