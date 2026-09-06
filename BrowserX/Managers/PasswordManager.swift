// Путь: BrowserX/Managers/PasswordManager.swift
import Foundation
import Combine

/// Одна сохранённая учётная запись сайта.
struct SavedCredential: Identifiable, Codable, Equatable {
    let id: UUID
    var host: String       // например "github.com"
    var username: String
    var createdAt: Date
    var lastUsedAt: Date

    init(id: UUID = UUID(), host: String, username: String, createdAt: Date = Date(), lastUsedAt: Date = Date()) {
        self.id = id
        self.host = host
        self.username = username
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

/// Управляет сохранёнными паролями. Метаданные (host/username) хранятся в UserDefaults,
/// а сам пароль — отдельно в Keychain (защищён Face ID/Touch ID), чтобы даже при компрометации
/// метаданных сам секрет оставался недоступен без биометрии.
@MainActor
final class PasswordManager: ObservableObject {

    @Published private(set) var credentials: [SavedCredential] = []

    private let metadataKey = "passwordManager.credentials"
    private let keychain = KeychainManager.shared

    init() {
        loadMetadata()
    }

    /// Сохраняет новую пару логин/пароль для хоста. Пароль кладётся в Keychain с требованием биометрии.
    func save(host: String, username: String, password: String) throws {
        let credential = SavedCredential(host: host, username: username)
        try keychain.save(password, forKey: keychainKey(for: credential), requiresBiometrics: true)

        credentials.removeAll { $0.host == host && $0.username == username }
        credentials.append(credential)
        persistMetadata()
    }

    /// Возвращает пароль, запрашивая Face ID/Touch ID через Keychain.
    func password(for credential: SavedCredential) throws -> String {
        try keychain.read(
            forKey: keychainKey(for: credential),
            prompt: "Разблокируйте, чтобы автозаполнить пароль для \(credential.host)"
        )
    }

    /// Ищет сохранённые учётные данные для конкретного хоста (для автозаполнения формы входа).
    func credentials(forHost host: String) -> [SavedCredential] {
        credentials.filter { $0.host == host }
    }

    func delete(_ credential: SavedCredential) {
        try? keychain.delete(forKey: keychainKey(for: credential))
        credentials.removeAll { $0.id == credential.id }
        persistMetadata()
    }

    func markUsed(_ credential: SavedCredential) {
        guard let index = credentials.firstIndex(of: credential) else { return }
        credentials[index].lastUsedAt = Date()
        persistMetadata()
    }

    /// Простая оценка силы пароля — используется UI при создании нового пароля.
    static func strength(of password: String) -> PasswordStrength {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .symbols.union(.punctuationCharacters)) != nil { score += 1 }

        switch score {
        case 0...1: return .weak
        case 2...3: return .medium
        default: return .strong
        }
    }

    /// Генерирует надёжный случайный пароль.
    static func generatePassword(length: Int = 16) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let digits = "0123456789"
        let symbols = "!@#$%^&*()-_=+"
        let all = letters + digits + symbols
        return String((0..<length).map { _ in all.randomElement()! })
    }

    private func keychainKey(for credential: SavedCredential) -> String {
        "password.\(credential.host).\(credential.username)"
    }

    private func persistMetadata() {
        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: metadataKey)
        }
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let items = try? JSONDecoder().decode([SavedCredential].self, from: data) else { return }
        credentials = items
    }
}

enum PasswordStrength: String {
    case weak = "Слабый"
    case medium = "Средний"
    case strong = "Надёжный"
}
