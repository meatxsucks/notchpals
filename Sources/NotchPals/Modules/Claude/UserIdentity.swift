// Adaptado de Coucou (https://github.com/Louis-CFM/coucou), licencia MIT. Ver THIRD_PARTY_NOTICES.md.
import Foundation

/// Nombre de pila del titular de la cuenta de macOS, o nil si el nombre no es algo con lo que se salude a una persona.
/// «Théodore Riant» da «Théodore»; un usuario como «theodoreriant» o «t.riant2» da nil, porque
/// «Hola theodoreriant» queda peor que un saludo sin nombre.
func resolveUserFirstName() -> String? {
    firstName(fromFullName: NSFullUserName())
}

/// Parte pura y testeable de `resolveUserFirstName`.
func firstName(fromFullName raw: String) -> String? {
    let fullName = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !fullName.isEmpty, fullName.count <= maxUserFullNameLength else { return nil }
    guard !looksLikeLoginHandle(fullName) else { return nil }

    guard let first = fullName.split(separator: " ").first.map(String.init),
          !first.isEmpty,
          first.allSatisfy(isNamePart) else { return nil }
    return first
}

/// `NSFullUserName()` devuelve el nombre corto de la cuenta cuando no hay nombre completo, así que una sola
/// palabra en minúsculas, o con dígitos o separadores, se trata como un nombre de usuario.
private func looksLikeLoginHandle(_ name: String) -> Bool {
    guard !name.contains(" ") else { return false }
    return name == name.lowercased() || name.contains(where: isHandleMarker)
}

private func isHandleMarker(_ character: Character) -> Bool {
    character.isNumber || "._-@".contains(character)
}

private func isNamePart(_ character: Character) -> Bool {
    character.isLetter || character == "'" || character == "-"
}

private let maxUserFullNameLength = 32
