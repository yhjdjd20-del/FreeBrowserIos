// Путь: BrowserX/Extensions/BrowserExtension.swift
import Foundation
import WebKit

/// Базовый протокол, который должно реализовать любое расширение BrowserX.
/// Расширения могут внедрять CSS/JS в страницы (через WKUserScript) и реагировать
/// на события жизненного цикла страницы.
protocol BrowserExtension: Identifiable where ID == String {
    /// Уникальный, стабильный идентификатор расширения (используется для persistence).
    var id: String { get }
    var displayName: String { get }
    var extensionDescription: String { get }
    var iconSystemName: String { get }

    /// Внедряет контент-скрипты/CSS в конфигурацию WKWebView до создания страницы.
    func inject(into configuration: WKWebViewConfiguration)

    /// Вызывается после того, как страница полностью загрузилась — удобно для
    /// пост-обработки DOM (например, детект RSS-ссылок, применение тёмной темы).
    func onPageFinishedLoading(webView: WKWebView, url: URL?)
}

extension BrowserExtension {
    /// Реализация по умолчанию — большинство расширений не требуют пост-обработки.
    func onPageFinishedLoading(webView: WKWebView, url: URL?) {}
}

/// Точки внедрения скрипта, аналог `chrome.runtime` document_start / document_end.
enum ContentScriptInjectionTime {
    case documentStart
    case documentEnd

    var wkTime: WKUserScriptInjectionTime {
        switch self {
        case .documentStart: return .atDocumentStart
        case .documentEnd: return .atDocumentEnd
        }
    }
}

/// Вспомогательная фабрика для создания WKUserScript с частыми настройками.
enum ContentScriptFactory {
    static func makeUserScript(
        source: String,
        injectionTime: ContentScriptInjectionTime,
        forMainFrameOnly: Bool = false
    ) -> WKUserScript {
        WKUserScript(
            source: source,
            injectionTime: injectionTime.wkTime,
            forMainFrameOnly: forMainFrameOnly
        )
    }
}
