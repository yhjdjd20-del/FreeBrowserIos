// Путь: BrowserX/Views/ReaderModeView.swift
import SwiftUI
import WebKit

/// Экран Reader Mode: извлекает основной текст статьи из активной вкладки и показывает
/// его в чистом, настраиваемом виде (размер шрифта, светлая/тёмная тема), плюс
/// кнопка "Суммаризировать через AI".
struct ReaderModeView: View {

    @ObservedObject var tab: Tab
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = AIService()

    @State private var articleHTML: String = ""
    @State private var articleTitle: String = ""
    @State private var fontSize: Double = 18
    @State private var isDarkBackground = false
    @State private var summary: String?
    @State private var isSummarizing = false
    @State private var summaryError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(articleTitle)
                        .font(.title.bold())

                    if let summary {
                        SummaryCard(text: summary)
                    }

                    ReaderHTMLView(html: articleHTML, fontSize: fontSize, isDarkBackground: isDarkBackground)
                        .frame(minHeight: 400)
                }
                .padding()
            }
            .background(isDarkBackground ? Color.black : Color(.systemBackground))
            .navigationTitle("Reader Mode")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { fontSize = max(12, fontSize - 2) }) {
                        Image(systemName: "textformat.size.smaller")
                    }
                    Button(action: { fontSize = min(32, fontSize + 2) }) {
                        Image(systemName: "textformat.size.larger")
                    }
                    Button(action: { isDarkBackground.toggle() }) {
                        Image(systemName: isDarkBackground ? "sun.max" : "moon")
                    }
                    Button(action: summarizeWithAI) {
                        if isSummarizing {
                            ProgressView()
                        } else {
                            Image(systemName: "sparkles")
                        }
                    }
                }
            }
            .alert("Не удалось суммаризировать", isPresented: .constant(summaryError != nil), actions: {
                Button("ОК") { summaryError = nil }
            }, message: {
                Text(summaryError ?? "")
            })
        }
        .task {
            tab.webViewController.extractReaderContent { html, title in
                articleHTML = html
                articleTitle = title.isEmpty ? tab.title : title
            }
        }
    }

    private func summarizeWithAI() {
        isSummarizing = true
        Task {
            do {
                let plainText = articleHTML.strippingHTMLTags()
                let result = try await aiService.summarize(pageText: plainText, pageTitle: articleTitle, model: "claude-sonnet-4-6")
                await MainActor.run {
                    summary = result
                    isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    summaryError = error.localizedDescription
                    isSummarizing = false
                }
            }
        }
    }
}

private struct SummaryCard: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI-суммаризация", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Простая обёртка, рендерящая извлечённый HTML статьи с заданным размером шрифта.
private struct ReaderHTMLView: View {
    let html: String
    let fontSize: Double
    let isDarkBackground: Bool

    var body: some View {
        // Для простоты рендерим как attributed-текст; для полноценной поддержки картинок
        // можно заменить на WKWebView с изолированной таблицей стилей.
        if let attributed = try? NSAttributedString(
            data: Data(styledHTML.utf8),
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        ) {
            Text(AttributedString(attributed))
        } else {
            Text(html.strippingHTMLTags())
                .font(.system(size: fontSize))
        }
    }

    private var styledHTML: String {
        let color = isDarkBackground ? "#EDEDED" : "#1C1C1E"
        return """
        <html><head><style>
        body { font-family: -apple-system; font-size: \(fontSize)px; color: \(color); }
        img { max-width: 100%; height: auto; }
        </style></head><body>\(html)</body></html>
        """
    }
}

private extension String {
    /// Грубое удаление HTML-тегов для передачи чистого текста в AI-суммаризацию.
    func strippingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
