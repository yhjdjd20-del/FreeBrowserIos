// Путь: BrowserX/Views/AddressBar.swift
import SwiftUI

/// Умная адресная строка: понимает, ввёл пользователь URL или поисковый запрос,
/// показывает индикатор загрузки/безопасности, и предоставляет быстрый доступ
/// к AI-чату, загрузкам, настройкам и Reader Mode.
struct AddressBar: View {

    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var userSettings: UserSettings

    @State private var editingText: String = ""
    @FocusState private var isFocused: Bool

    let onOpenChat: () -> Void
    let onOpenDownloads: () -> Void
    let onOpenSettings: () -> Void
    let onOpenReaderMode: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            navigationButtons

            HStack(spacing: 6) {
                securityIcon
                TextField("Поиск или адрес сайта", text: $editingText, onCommit: commit)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.webSearch)
                    #endif
                    .onAppear { syncEditingTextFromActiveTab() }
                    .onChange(of: tabManager.activeTabID) { _, _ in syncEditingTextFromActiveTab() }
                    .onChange(of: tabManager.activeTab?.url) { _, _ in
                        if !isFocused { syncEditingTextFromActiveTab() }
                    }

                if let tab = tabManager.activeTab, tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let tab = tabManager.activeTab, tab.readerModeAvailable {
                    Button(action: onOpenReaderMode) {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            actionButtons
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var navigationButtons: some View {
        HStack(spacing: 4) {
            Button(action: { tabManager.goBack() }) {
                Image(systemName: "chevron.left")
            }
            .disabled(tabManager.activeTab?.canGoBack != true)

            Button(action: { tabManager.goForward() }) {
                Image(systemName: "chevron.right")
            }
            .disabled(tabManager.activeTab?.canGoForward != true)

            Button(action: {
                if tabManager.activeTab?.isLoading == true {
                    tabManager.stopLoading()
                } else {
                    tabManager.reload()
                }
            }) {
                Image(systemName: tabManager.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise")
            }
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button(action: onOpenChat) {
                Image(systemName: "sparkles")
            }
            Button(action: onOpenDownloads) {
                Image(systemName: "arrow.down.circle")
            }
            Button(action: {
                tabManager.openNewTab(url: userSettings.homePageURL)
            }) {
                Image(systemName: "plus.square.on.square")
            }
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var securityIcon: some View {
        if let url = tabManager.activeTab?.url {
            Image(systemName: URLUtils.isSecure(url) ? "lock.fill" : "lock.open")
                .foregroundStyle(URLUtils.isSecure(url) ? .green : .orange)
                .font(.caption)
        }
    }

    private func syncEditingTextFromActiveTab() {
        guard let url = tabManager.activeTab?.url else {
            editingText = ""
            return
        }
        editingText = URLUtils.displayString(for: url)
    }

    private func commit() {
        isFocused = false
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if URLUtils.looksLikeURL(trimmed), let url = URLUtils.normalizedURL(from: trimmed) {
            tabManager.load(url: url)
        } else {
            let searchURL = userSettings.searchEngine.searchURL(for: trimmed)
            tabManager.load(url: searchURL)
        }
    }
}
