// Путь: BrowserX/Utilities/CustomExtension.swift
import Foundation
import WebKit

/// Расширение-блокировщик рекламы: внедряет CSS, скрывающий распространённые рекламные блоки.
struct AdBlockExtension: BrowserExtension {
    static let staticID = "com.browserx.adblock"
    var id: String { Self.staticID }
    var displayName: String { "Ad Blocker" }
    var extensionDescription: String { "Блокирует баннеры и всплывающую рекламу на сайтах" }
    var iconSystemName: String { "shield.slash" }

    func inject(into configuration: WKWebViewConfiguration) {
        let script = ContentScriptFactory.makeUserScript(
            source: ContentScripts.adBlockCSS,
            injectionTime: .documentEnd
        )
        configuration.userContentController.addUserScript(script)
    }
}

/// Расширение принудительной тёмной темы для сайтов без нативного dark-mode.
struct DarkReaderExtension: BrowserExtension {
    static let staticID = "com.browserx.darkreader"
    var id: String { Self.staticID }
    var displayName: String { "Dark Reader" }
    var extensionDescription: String { "Принудительная тёмная тема для любого сайта" }
    var iconSystemName: String { "moon.stars" }

    func inject(into configuration: WKWebViewConfiguration) {
        let script = ContentScriptFactory.makeUserScript(
            source: ContentScripts.darkReaderCSS,
            injectionTime: .documentEnd
        )
        configuration.userContentController.addUserScript(script)
    }
}

/// Расширение-детектор RSS/Atom фидов — сообщает Swift-коду о найденных фидах через message handler.
final class RSSDetectorExtension: NSObject, BrowserExtension, WKScriptMessageHandler {
    static let staticID = "com.browserx.rssdetector"
    var id: String { Self.staticID }
    var displayName: String { "RSS Detector" }
    var extensionDescription: String { "Обнаруживает RSS/Atom ленты на странице" }
    var iconSystemName: String { "dot.radiowaves.up.forward" }

    /// Публикует найденные фиды для подписчиков (например, ChatSidebar или отдельного RSS-ридера).
    static let feedsDidUpdateNotification = Notification.Name("browserX.rssFeedsDidUpdate")

    func inject(into configuration: WKWebViewConfiguration) {
        configuration.userContentController.add(self, name: "browserXRSS")
    }

    func onPageFinishedLoading(webView: WKWebView, url: URL?) {
        webView.evaluateJavaScript(ContentScripts.rssDetectorJS, completionHandler: nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let feeds = message.body as? [[String: String]] else { return }
        NotificationCenter.default.post(
            name: Self.feedsDidUpdateNotification,
            object: nil,
            userInfo: ["feeds": feeds]
        )
    }
}

/// Пример пользовательского расширения, которое можно использовать как шаблон для написания своих:
/// добавляет плавающую кнопку "Сохранить в закладки" на каждой странице.
struct QuickBookmarkExtension: BrowserExtension {
    var id: String { "com.browserx.quickbookmark" }
    var displayName: String { "Quick Bookmark" }
    var extensionDescription: String { "Плавающая кнопка быстрого добавления в закладки" }
    var iconSystemName: String { "bookmark.circle" }

    private var buttonJS: String {
        """
        (function() {
            if (document.getElementById('browserx-quick-bookmark')) { return; }
            const btn = document.createElement('div');
            btn.id = 'browserx-quick-bookmark';
            btn.style.cssText = 'position:fixed;bottom:24px;right:24px;width:48px;height:48px;border-radius:24px;background:#007AFF;z-index:999999;box-shadow:0 2px 8px rgba(0,0,0,0.3);';
            document.body.appendChild(btn);
            btn.addEventListener('click', function() {
                if (window.webkit && window.webkit.messageHandlers.browserXQuickBookmark) {
                    window.webkit.messageHandlers.browserXQuickBookmark.postMessage({ url: window.location.href, title: document.title });
                }
            });
        })();
        """
    }

    func inject(into configuration: WKWebViewConfiguration) {
        let script = ContentScriptFactory.makeUserScript(source: buttonJS, injectionTime: .documentEnd)
        configuration.userContentController.addUserScript(script)
    }
}
