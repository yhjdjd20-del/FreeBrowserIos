// Путь: BrowserX/Views/ChatSidebar.swift
import SwiftUI

/// Боковая панель чата с AI-ассистентом (Claude). Позволяет задавать вопросы про
/// текущую страницу, получать суммаризацию, и вести свободный диалог.
struct ChatSidebar: View {

    let currentURL: URL?

    @EnvironmentObject var userSettings: UserSettings
    @StateObject private var aiService = AIService()
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [AIChatMessage] = []
    @State private var draftText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !aiService.hasAPIKey() {
                    missingKeyBanner
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if aiService.isLoading {
                                ProgressView().padding(.leading, 8)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()
                inputBar
            }
            .navigationTitle("AI Assistant")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .alert("Ошибка", isPresented: .constant(errorMessage != nil), actions: {
                Button("ОК") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var missingKeyBanner: some View {
        HStack {
            Image(systemName: "key.slash")
            Text("Добавьте API-ключ Claude в Настройках, чтобы начать диалог")
                .font(.caption)
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.15))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Спросите что-нибудь про страницу...", text: $draftText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading)
        }
        .padding()
    }

    private func send() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = AIChatMessage(role: .user, text: text)
        messages.append(userMessage)
        draftText = ""

        Task {
            do {
                let reply = try await aiService.sendMessage(history: messages, model: userSettings.claudeModel)
                await MainActor.run {
                    messages.append(AIChatMessage(role: .assistant, text: reply))
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

private struct MessageBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(message.text)
            .font(.subheadline)
            .padding(10)
            .background(message.role == .user ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(message.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
