// Путь: BrowserX/Views/SettingsView.swift
import SwiftUI

/// Главный экран настроек. Разбит на секции: Общие, Приватность, Расширения,
/// Пароли (Face ID), AI Assistant (Claude API key).
struct SettingsView: View {

    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var extensionManager: ExtensionManager
    @EnvironmentObject var passwordManager: PasswordManager
    @Environment(\.dismiss) private var dismiss

    @State private var homePageText: String = ""
    @State private var apiKeyText: String = ""
    @State private var apiKeySaveError: String?
    @State private var apiKeySavedConfirmation = false

    private let aiService = AIService()

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                privacySection
                extensionsSection
                passwordsSection
                aiSection
            }
            .navigationTitle("Настройки")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                homePageText = URLUtils.displayString(for: userSettings.homePageURL)
            }
        }
    }

    // MARK: - Общие

    private var generalSection: some View {
        Section("Общие") {
            HStack {
                Text("Домашняя страница")
                Spacer()
                TextField("example.com", text: $homePageText)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .onSubmit {
                        if let url = URLUtils.normalizedURL(from: homePageText) {
                            userSettings.homePageURL = url
                        }
                    }
            }

            Picker("Поисковая система", selection: $userSettings.searchEngine) {
                ForEach(UserSettings.SearchEngine.allCases) { engine in
                    Text(engine.displayName).tag(engine)
                }
            }

            Toggle("Тёмная тема", isOn: $userSettings.isDarkMode)
            Toggle("Автоопределение Reader Mode", isOn: $userSettings.readerModeAutoDetect)
        }
    }

    // MARK: - Приватность

    private var privacySection: some View {
        Section("Приватность и безопасность") {
            Toggle("Блокировщик рекламы", isOn: Binding(
                get: { userSettings.isAdBlockEnabled },
                set: { newValue in
                    userSettings.isAdBlockEnabled = newValue
                    if let ext = extensionManager.installedExtensions.first(where: { $0.id == AdBlockExtension.staticID }) {
                        extensionManager.setEnabled(newValue, for: ext)
                    }
                }
            ))
            Toggle("Не отслеживать (Do Not Track)", isOn: $userSettings.doNotTrack)
            Toggle("Синхронизация между устройствами", isOn: $userSettings.isSyncEnabled)
        }
    }

    // MARK: - Расширения

    private var extensionsSection: some View {
        Section("Расширения") {
            ForEach(extensionManager.installedExtensions, id: \.id) { ext in
                Toggle(isOn: Binding(
                    get: { extensionManager.isEnabled(ext) },
                    set: { extensionManager.setEnabled($0, for: ext) }
                )) {
                    HStack {
                        Image(systemName: ext.iconSystemName)
                        VStack(alignment: .leading) {
                            Text(ext.displayName)
                            Text(ext.extensionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Пароли

    private var passwordsSection: some View {
        Section("Пароли") {
            Toggle("Face ID / Touch ID для паролей", isOn: $userSettings.faceIDForPasswordsEnabled)

            NavigationLink("Управление сохранёнными паролями (\(passwordManager.credentials.count))") {
                PasswordListView()
                    .environmentObject(passwordManager)
            }
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        Section {
            SecureField("Claude API Key (sk-ant-...)", text: $apiKeyText)
                .textContentType(.password)

            Button("Сохранить ключ") {
                do {
                    try aiService.saveAPIKey(apiKeyText, requiresBiometrics: userSettings.faceIDForPasswordsEnabled)
                    apiKeySavedConfirmation = true
                    apiKeyText = ""
                } catch {
                    apiKeySaveError = error.localizedDescription
                }
            }
            .disabled(apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Picker("Модель Claude", selection: $userSettings.claudeModel) {
                Text("Claude Sonnet 4.6").tag("claude-sonnet-4-6")
                Text("Claude Opus 4.6").tag("claude-opus-4-6")
                Text("Claude Haiku 4.5").tag("claude-haiku-4-5-20251001")
            }
        } header: {
            Text("AI Assistant")
        } footer: {
            Text("Ключ хранится только в Keychain на этом устройстве и никогда не покидает его, кроме прямых запросов к api.anthropic.com.")
        }
        .alert("Ключ сохранён", isPresented: $apiKeySavedConfirmation) {
            Button("ОК", role: .cancel) {}
        }
        .alert("Ошибка сохранения ключа", isPresented: .constant(apiKeySaveError != nil)) {
            Button("ОК") { apiKeySaveError = nil }
        } message: {
            Text(apiKeySaveError ?? "")
        }
    }
}

/// Экран списка сохранённых паролей с раскрытием пароля через Face ID.
private struct PasswordListView: View {
    @EnvironmentObject var passwordManager: PasswordManager
    @State private var revealedPassword: String?
    @State private var revealError: String?

    var body: some View {
        List {
            ForEach(passwordManager.credentials) { credential in
                VStack(alignment: .leading, spacing: 4) {
                    Text(credential.host).font(.headline)
                    Text(credential.username).font(.caption).foregroundStyle(.secondary)
                    if revealedPassword != nil {
                        Text(revealedPassword ?? "").font(.system(.caption, design: .monospaced))
                    }
                }
                .swipeActions {
                    Button("Показать") { reveal(credential) }
                    Button("Удалить", role: .destructive) { passwordManager.delete(credential) }
                }
            }
        }
        .navigationTitle("Пароли")
        .alert("Не удалось показать пароль", isPresented: .constant(revealError != nil)) {
            Button("ОК") { revealError = nil }
        } message: {
            Text(revealError ?? "")
        }
    }

    private func reveal(_ credential: SavedCredential) {
        do {
            revealedPassword = try passwordManager.password(for: credential)
            passwordManager.markUsed(credential)
        } catch {
            revealError = error.localizedDescription
        }
    }
}
