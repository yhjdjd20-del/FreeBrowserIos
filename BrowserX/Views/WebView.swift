// Путь: BrowserX/Views/WebView.swift
import SwiftUI
import WebKit
import Combine

/// Контроллер, владеющий WKWebView для одной вкладки. Живёт внутри Tab, переживает
/// пересоздание SwiftUI-иерархии (в отличие от UIViewRepresentable.Coordinator).
@MainActor
final class WebViewController: NSObject {

    private(set) var webView: WKWebView?
    private let isPrivate: Bool

    weak var downloadManager: DownloadManager?
    weak var extensionManager: ExtensionManager?
    weak var ownerTab: Tab?

    private var cancellables = Set<AnyCancellable>()
    private var kvoObservations: [NSKeyValueObservation] = []

    init(isPrivate: Bool) {
        self.isPrivate = isPrivate
        super.init()
    }

    /// Ленивая настройка WKWebView — вызывается один раз при первом появлении на экране,
    /// чтобы применить все включённые расширения к конфигурации.
    func makeWebViewIfNeeded(extensionManager: ExtensionManager) -> WKWebView {
        if let webView { return webView }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.allowsInlineMediaPlayback = true
        extensionManager.applyEnabledExtensions(to: configuration)

        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        newWebView.navigationDelegate = self
        newWebView.uiDelegate = self
        newWebView.allowsBackForwardNavigationGestures = true
        #if os(iOS)
        newWebView.scrollView.contentInsetAdjustmentBehavior = .automatic
        #endif

        observeWebView(newWebView)
        self.webView = newWebView
        self.extensionManager = extensionManager
        return newWebView
    }

    func load(url: URL) {
        guard let webView else { return }
        webView.load(URLRequest(url: url))
    }

    /// Захватывает PNG-снимок текущей страницы для превью вкладки.
    func captureSnapshot(completion: @escaping (Data?) -> Void) {
        guard let webView else { completion(nil); return }
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, _ in
            #if os(iOS)
            completion(image?.pngData())
            #else
            completion(image?.tiffRepresentation)
            #endif
        }
    }

    /// Извлекает основной текст статьи для Reader Mode / AI-суммаризации.
    func extractReaderContent(completion: @escaping (String, String) -> Void) {
        webView?.evaluateJavaScript(ContentScripts.readerModeExtractionJS) { result, _ in
            guard let dict = result as? [String: Any] else {
                completion("", "")
                return
            }
            let html = dict["html"] as? String ?? ""
            let title = dict["title"] as? String ?? ""
            completion(html, title)
        }
    }

    private func observeWebView(_ webView: WKWebView) {
        // Наблюдаем за прогрессом/заголовком через Combine KVO-паблишеры WKWebView.
        webView.publisher(for: \.estimatedProgress)
            .sink { [weak self] _ in self?.ownerTab?.syncFromWebView() }
            .store(in: &cancellables)

        webView.publisher(for: \.title)
            .sink { [weak self] _ in self?.ownerTab?.syncFromWebView() }
            .store(in: &cancellables)

        webView.publisher(for: \.isLoading)
            .sink { [weak self] _ in self?.ownerTab?.syncFromWebView() }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoBack)
            .sink { [weak self] _ in self?.ownerTab?.syncFromWebView() }
            .store(in: &cancellables)

        webView.publisher(for: \.canGoForward)
            .sink { [weak self] _ in self?.ownerTab?.syncFromWebView() }
            .store(in: &cancellables)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ownerTab?.syncFromWebView()
        if let extensionManager {
            extensionManager.notifyPageDidFinishLoading(webView: webView, url: webView.url)
        }
        webView.evaluateJavaScript(ContentScripts.readerModeExtractionJS) { [weak self] result, _ in
            guard let dict = result as? [String: Any], let html = dict["html"] as? String else { return }
            Task { @MainActor in
                self?.ownerTab?.readerModeAvailable = html.count > 800
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.ownerTab?.lastError = error.localizedDescription }
    }

    /// Перехватывает навигацию, которая должна привести к скачиванию файла (Content-Disposition: attachment),
    /// и передаёт её в DownloadManager вместо загрузки в WKWebView.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !navigationResponse.canShowMIMEType, let url = navigationResponse.response.url {
            downloadManager?.startDownload(from: url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {
    /// Открывает `target="_blank"` ссылки в той же вкладке (упрощённая обработка popup).
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

// MARK: - SwiftUI-обёртка

#if os(iOS)
import UIKit

struct WebView: UIViewRepresentable {
    @ObservedObject var tab: Tab
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var extensionManager: ExtensionManager

    func makeUIView(context: Context) -> WKWebView {
        tab.webViewController.ownerTab = tab
        tab.webViewController.downloadManager = downloadManager
        let webView = tab.webViewController.makeWebViewIfNeeded(extensionManager: extensionManager)
        if webView.url == nil {
            webView.load(URLRequest(url: tab.url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Навигация инициируется через TabManager.load(url:), поэтому здесь ничего не делаем,
        // чтобы избежать лишних перезагрузок при каждом обновлении SwiftUI-состояния.
    }
}
#else
struct WebView: NSViewRepresentable {
    @ObservedObject var tab: Tab
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var extensionManager: ExtensionManager

    func makeNSView(context: Context) -> WKWebView {
        tab.webViewController.ownerTab = tab
        tab.webViewController.downloadManager = downloadManager
        let webView = tab.webViewController.makeWebViewIfNeeded(extensionManager: extensionManager)
        if webView.url == nil {
            webView.load(URLRequest(url: tab.url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
