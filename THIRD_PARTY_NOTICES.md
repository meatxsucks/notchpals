# Avisos de terceros

## Coucou
Partes de NotchPals están adaptadas de [Coucou](https://github.com/Louis-CFM/coucou) (Louis Raillé), publicado bajo licencia MIT:

- `Modules/Claude/UserIdentity.swift`: resolución del nombre de pila del usuario.
- `Modules/Claude/LocalLLMClient.swift`: conexión a servidores locales con API compatible con OpenAI, filtrado de bloques `<think>`, lista de modelos.
- `Modules/Claude/ChatPrompt.swift`: apertura del prompt (asistente personal en el notch, saludo por nombre).
- Diseño del hook de aprobaciones (`PermissionRequest`) y de la instalación en `~/.claude/settings.json`.

El nombre Coucou, la mascota Mochi y los sonidos **no** se incluyen: son propiedad de su autor y no están bajo licencia MIT.

```
MIT License

Copyright (c) 2026 Louis Raillé

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
