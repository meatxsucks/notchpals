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
