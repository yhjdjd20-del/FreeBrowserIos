// Путь: BrowserX/Models/Tab.swift
import Foundation
import Combine
import WebKit

/// Представляет одну вкладку браузера.
/// Является `ObservableObject`, чтобы UI (AddressBar, TabSidebarStripView, WebView)
/// мог реактивно обновляться при изменении заголовка, URL, прогресса загрузки и т.д.
@MainActor
final class Tab: ObservableObject, Identifiable, Equatable, Hashable {

    let id: UUID = UUID()

    @Published var url: URL
    @Published var title: String = "Новая вкладка"
    @Published var faviconData: Data?
    @Published var estimatedProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isPrivate: Bool = false
    @Published var snapshot: Data? // PNG-снимок страницы для превью вкладки
    @Published var readerModeAvailable: Bool = false
    @Published var lastError: String?

    /// Собственный WKWebView-контроллер для этой вкладки — переживает пересоздание SwiftUI-view.
    let webViewController: WebViewController

    var createdAt: Date = Date()

    init(url: URL, isPrivate: Bool = false) {
        self.url = url
        self.isPrivate = isPrivate
        self.webViewController = WebViewController(isPrivate: isPrivate)
    }

    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Обновляет заголовок/URL из состояния WKWebView (вызывается из WebViewController.Coordinator).
    func syncFromWebView() {
        guard let webView = webViewController.webView else { return }
        title = webView.title?.isEmpty == false ? webView.title! : title
        if let currentURL = webView.url {
            url = currentURL
        }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        estimatedProgress = webView.estimatedProgress
        isLoading = webView.isLoading
    }
}
