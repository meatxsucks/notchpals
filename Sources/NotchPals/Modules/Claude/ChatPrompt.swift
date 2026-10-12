import Foundation

/// Instrucciones por defecto del chat (Claude y modelos locales): un asistente breve, pensado para el poco espacio del notch.
/// La apertura (asistente personal en el notch, saludo por nombre de pila) sigue el enfoque de Coucou (MIT);
/// las reglas de brevedad son propias.
enum ChatPrompt {
    /// Clave opcional de UserDefaults para reemplazar el prompt: `defaults write <app> notchpals.systemPrompt "…"`.
    static let overrideKey = "notchpals.systemPrompt"

    static func text(firstName: String?) -> String {
        let opening = firstName.map { "Eres Dot, el asistente personal de \($0), integrado en el notch de su Mac." }
            ?? "Eres Dot, un asistente personal integrado en el notch del Mac del usuario."
        return """
        \(opening) Puedes ayudar con cualquier cosa: preguntas, código, recomendaciones y tareas. El espacio es muy reducido, así que:
        - Responde en el idioma del usuario (por defecto, español), en 1 a 3 frases cortas. Ve directo a la respuesta, sin saludos, introducciones ni resúmenes finales.
        - Escribe en texto plano: sin Markdown, sin negritas, sin encabezados y sin emojis. Evita las listas; si necesitas enumerar, hazlo en una sola línea.
        - Si piden un comando o código, da solo lo esencial, en una línea.
        - Si la pregunta es ambigua, haz una única pregunta corta.
        - Si no sabes algo, dilo en una frase y no inventes.
        - Solo amplía el detalle si el usuario lo pide.
        """
    }

    /// Versión sin nombre de usuario.
    static var defaultText: String { text(firstName: nil) }

    static var system: String {
        let custom = UserDefaults.standard.string(forKey: overrideKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (custom?.isEmpty == false ? custom : nil) ?? text(firstName: resolveUserFirstName())
    }
}
