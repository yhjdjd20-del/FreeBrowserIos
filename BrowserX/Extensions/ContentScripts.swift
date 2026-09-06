// Путь: BrowserX/Extensions/ContentScripts.swift
import Foundation

/// Централизованное хранилище JS/CSS сниппетов, которые используют встроенные расширения.
/// Вынесено отдельно от логики расширений, чтобы скрипты было легко тестировать/обновлять.
enum ContentScripts {

    /// Базовый CSS-блокировщик — скрывает распространённые рекламные контейнеры по селекторам.
    static let adBlockCSS = """
    (function() {
        const style = document.createElement('style');
        style.id = 'browserx-adblock-style';
        style.textContent = `
            [id*="google_ads"], [class*="ad-banner"], [class*="advert"],
            iframe[src*="doubleclick"], div[class*="sponsored"],
            .ad-container, .adsbygoogle { display: none !important; }
        `;
        document.documentElement.appendChild(style);
    })();
    """

    /// Инвертирует цвета/применяет тёмную схему на сайтах без нативной поддержки dark-mode.
    static let darkReaderCSS = """
    (function() {
        if (document.getElementById('browserx-dark-style')) { return; }
        const style = document.createElement('style');
        style.id = 'browserx-dark-style';
        style.textContent = `
            html { background: #121212 !important; }
            body, article, section, div { background-color: #121212 !important; color: #e0e0e0 !important; }
            a { color: #8ab4f8 !important; }
            img, video, picture { filter: brightness(0.85) contrast(1.05); }
        `;
        document.documentElement.appendChild(style);
    })();
    """

    /// Находит все `<link rel="alternate" type="application/rss+xml">` на странице и возвращает их через
    /// window.webkit.messageHandlers, чтобы Swift-код (RSSDetectorExtension) мог показать иконку RSS.
    static let rssDetectorJS = """
    (function() {
        const links = Array.from(document.querySelectorAll('link[type="application/rss+xml"], link[type="application/atom+xml"]'));
        const feeds = links.map(l => ({ href: l.href, title: l.title || 'RSS Feed' }));
        if (feeds.length > 0 && window.webkit && window.webkit.messageHandlers.browserXRSS) {
            window.webkit.messageHandlers.browserXRSS.postMessage(feeds);
        }
    })();
    """

    /// Извлекает основной текст статьи для Reader Mode (упрощённая readability-эвристика).
    static let readerModeExtractionJS = """
    (function() {
        function scoreNode(node) {
            const text = node.innerText || '';
            return text.length;
        }
        const candidates = Array.from(document.querySelectorAll('article, main, [role="main"], .post, .article-body'));
        let best = null;
        let bestScore = 0;
        for (const c of candidates) {
            const s = scoreNode(c);
            if (s > bestScore) { bestScore = s; best = c; }
        }
        if (!best) { best = document.body; }
        return {
            title: document.title,
            html: best.innerHTML,
            byline: (document.querySelector('meta[name="author"]') || {}).content || ''
        };
    })();
    """

    /// Скрипт для получения favicon/метаданных сайта (упрощённая версия).
    static let metadataExtractionJS = """
    (function() {
        const metaDesc = document.querySelector('meta[name="description"]');
        return {
            title: document.title,
            description: metaDesc ? metaDesc.content : '',
            themeColor: (document.querySelector('meta[name="theme-color"]') || {}).content || ''
        };
    })();
    """
}
