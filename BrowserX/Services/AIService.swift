// Путь: BrowserX/Services/AIService.swift
import Foundation

/// Роль сообщения в диалоге с Claude.
enum AIMessageRole: String, Codable {
    case user
    case assistant
}

/// Одно сообщение чата с ИИ-ассистентом.
struct AIChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: AIMessageRole
    var text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: AIMessageRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case network(Error)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Не задан API-ключ Claude. Откройте Настройки → AI Assistant, чтобы добавить его."
        case .invalidResponse:
            return "Не удалось разобрать ответ от Claude API."
        case .network(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .api(let message):
            return "Ошибка Claude API: \(message)"
        }
    }
}

/// Обёртка над Anthropic Messages API. Ключ читается из Keychain (см. KeychainManager),
/// либо, для отладки, из переменной окружения CLAUDE_API_KEY.
@MainActor
final class AIService: ObservableObject {

    @Published private(set) var isLoading = false

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"
    private let keychainKey = "com.browserx.claude-api-key"

    /// Сохраняет ключ пользователя в Keychain (защищён Face ID, если включено в настройках).
    func saveAPIKey(_ key: String, requiresBiometrics: Bool) throws {
        try KeychainManager.shared.save(key, forKey: keychainKey, requiresBiometrics: requiresBiometrics)
    }

    func hasAPIKey() -> Bool {
        (try? currentAPIKey()) != nil
    }

    private func currentAPIKey() throws -> String {
        if let envKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return try KeychainManager.shared.read(forKey: keychainKey, prompt: "Разблокируйте, чтобы использовать AI-ассистента")
    }

    /// Отправляет историю чата и возвращает ответ ассистента одним куском (без стриминга).
    func sendMessage(history: [AIChatMessage], model: String) async throws -> String {
        let apiKey = try currentAPIKey()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let payload = MessagesRequest(
            model: model,
            max_tokens: 1024,
            messages: history.map { MessagesRequest.Message(role: $0.role.rawValue, content: $0.text) }
        )
        request.httpBody = try JSONEncoder().encode(payload)

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
                    ?? "HTTP \(httpResponse.statusCode)"
                throw AIServiceError.api(message)
            }

            let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
            let text = decoded.content.compactMap { $0.text }.joined()
            return text
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.network(error)
        }
    }

    /// Удобный метод для суммаризации текста страницы (используется Reader Mode / ChatSidebar).
    func summarize(pageText: String, pageTitle: String, model: String) async throws -> String {
        let prompt = """
        Суммаризируй следующую веб-страницу на русском языке в 3-5 предложениях.
        Заголовок страницы: \(pageTitle)

        Текст страницы:
        \(pageText.prefix(12000))
        """
        let history = [AIChatMessage(role: .user, text: prompt)]
        return try await sendMessage(history: history, model: model)
    }
}

// MARK: - Codable-модели Anthropic Messages API

private struct MessagesRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let model: String
    let max_tokens: Int
    let messages: [Message]
}

private struct MessagesResponse: Codable {
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
    let content: [ContentBlock]
}

private struct APIErrorEnvelope: Codable {
    struct APIError: Codable {
        let type: String
        let message: String
    }
    let error: APIError
}
