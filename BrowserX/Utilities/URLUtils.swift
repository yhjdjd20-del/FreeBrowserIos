// Путь: BrowserX/Utilities/URLUtils.swift
import Foundation

/// Набор помощников для умной адресной строки: определить, ввёл ли пользователь URL
/// или поисковый запрос, нормализовать ввод, добавить схему по умолчанию и т.д.
enum URLUtils {

    /// Определяет, похож ли введённый пользователем текст на URL (а не на поисковый запрос).
    static func looksLikeURL(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return true
        }

        // Простая эвристика: есть точка, нет пробелов, похоже на домен.
        let hasSpaces = trimmed.contains(" ")
        let hasDot = trimmed.contains(".")
        let isLocalhost = trimmed.hasPrefix("localhost")

        if hasSpaces { return false }
        if isLocalhost { return true }
        if hasDot {
            // Отсекаем случаи вида "3.14" или "версия 5.0" (уже исключено по hasSpaces),
            // проверяем что после последней точки только буквы (TLD).
            let components = trimmed.split(separator: ".")
            if let lastComponent = components.last,
               lastComponent.count >= 2,
               lastComponent.allSatisfy({ $0.isLetter }) {
                return true
            }
        }
        return false
    }

    /// Приводит введённый текст к валидному URL, добавляя схему https:// если нужно.
    static func normalizedURL(from input: String) -> URL? {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }
        return URL(string: trimmed)
    }

    /// Возвращает "чистый" хост без www. — удобно для отображения и как ключ для паролей/расширений.
    static func cleanHost(from url: URL) -> String {
        var host = url.host ?? ""
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    /// Форматирует URL для отображения в адресной строке (скрывает схему https://, оставляет остальное).
    static func displayString(for url: URL) -> String {
        var string = url.absoluteString
        for prefix in ["https://", "http://"] {
            if string.hasPrefix(prefix) {
                string.removeFirst(prefix.count)
                break
            }
        }
        if string.hasSuffix("/") {
            string.removeLast()
        }
        return string
    }

    /// Проверяет, является ли URL защищённым (https) — для индикатора замка в адресной строке.
    static func isSecure(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }
}
