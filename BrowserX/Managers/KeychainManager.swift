// Путь: BrowserX/Managers/KeychainManager.swift
import Foundation
import Security
import LocalAuthentication

/// Ошибки при работе с Keychain.
enum KeychainError: LocalizedError {
    case unhandled(OSStatus)
    case itemNotFound
    case encodingFailed
    case biometricsFailed(String)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status): return "Ошибка Keychain: код \(status)"
        case .itemNotFound: return "Элемент не найден в Keychain"
        case .encodingFailed: return "Не удалось преобразовать данные"
        case .biometricsFailed(let reason): return "Аутентификация не удалась: \(reason)"
        }
    }
}

/// Тонкая, но безопасная обёртка над Keychain Services API.
/// Используется PasswordManager и AIService (для хранения Claude API-ключа) — доступ к секретам
/// защищён Face ID / Touch ID через LAContext, где это уместно.
struct KeychainManager {

    static let shared = KeychainManager()

    private let service = "com.browserx.secure"

    /// Сохраняет строку в Keychain под заданным ключом (аккаунтом).
    func save(_ value: String, forKey key: String, requiresBiometrics: Bool = false) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.encodingFailed }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Удаляем существующий элемент перед перезаписью.
        SecItemDelete(query as CFDictionary)

        if requiresBiometrics {
            var accessError: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                &accessError
            ) else {
                throw KeychainError.unhandled(errSecParam)
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    /// Читает строку из Keychain. Если элемент защищён биометрией, система сама покажет Face ID/Touch ID.
    func read(forKey key: String, prompt: String = "Разблокируйте, чтобы получить доступ") throws -> String {
        let context = LAContext()
        context.localizedReason = prompt

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.unhandled(status)
        }

        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.encodingFailed
        }
        return value
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    /// Проверка доступности биометрии на устройстве (для UI — показывать переключатель Face ID или нет).
    func biometryAvailable() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    /// Явный запрос Face ID / Touch ID для операций, требующих подтверждения (например, показать пароль).
    func authenticateWithBiometrics(reason: String) async throws {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !success {
                throw KeychainError.biometricsFailed("Аутентификация отклонена")
            }
        } catch {
            throw KeychainError.biometricsFailed(error.localizedDescription)
        }
    }
}
