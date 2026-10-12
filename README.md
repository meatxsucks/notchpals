# NotchPals

Convierte el notch del Mac en un panel de herramientas: música, calendario, portapapeles, bandeja de archivos,
atajos y un módulo **Claude** (chat, sesiones en vivo y aprobaciones de Claude Code). Incluye a **Dot**, una mascota
dibujada en código. App nativa en SwiftUI/AppKit, sin dependencias.

## Instalar y probar
Necesitas macOS 13+ y Xcode 15+ (o sus herramientas de línea de comandos).

```bash
git clone -b claude/scaffold https://github.com/meatxsucks/notchpals.git
cd notchpals
./scripts/build-app.sh        # genera dist/NotchPals.app
open dist/NotchPals.app
```
También puedes abrir `Package.swift` en Xcode y pulsar ⌘R. Con la `.app`, macOS puede pedir permisos (Calendario,
Automatización para Spotify/Música) la primera vez que uses cada módulo.

## Claude Code desde el notch
En la pestaña **Claude → Hook** pulsa *Instalar…*: muestra los cambios a `~/.claude/settings.json`, guarda una copia
con fecha y solo escribe cuando confirmas. Después, las aprobaciones de permisos y las sesiones en vivo aparecen en el notch.

El **chat** funciona con dos motores, que eliges arriba del chat:
- **Claude**: API de Anthropic con tu propia API key, guardada en el llavero de macOS.
- **Ollama**: tu servidor local (`ollama serve`, por defecto `http://127.0.0.1:11434`). Sin API key; elige el modelo en el menú y la respuesta llega en streaming. Acepta texto e imágenes (con un modelo de visión); los PDF no.

Más detalles de diseño en [PLAN.md](PLAN.md).
