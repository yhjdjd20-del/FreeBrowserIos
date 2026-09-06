// Путь: BrowserX/Managers/ExtensionManager.swift
import Foundation
import Combine
import WebKit

/// Управляет установленными расширениями браузера: регистрация, включение/выключение,
/// применение content scripts к WKWebView.
@MainActor
final class ExtensionManager: ObservableObject {

    @Published private(set) var installedExtensions: [any BrowserExtension] = []
    @Published private(set) var enabledExtensionIDs: Set<String> = []

    private let enabledKey = "extensionManager.enabledIDs"

    init() {
        if let saved = UserDefaults.standard.array(forKey: enabledKey) as? [String] {
            enabledExtensionIDs = Set(saved)
        }
    }

    /// Регистрирует набор встроенных расширений по умолчанию (Ad Blocker, Dark Reader, RSS Reader).
    func registerBuiltInExtensions() {
        register(AdBlockExtension())
        register(DarkReaderExtension())
        register(RSSDetectorExtension())

        // По умолчанию включаем блокировщик рекламы.
        if enabledExtensionIDs.isEmpty {
            enabledExtensionIDs = [AdBlockExtension.staticID]
            persist()
        }
    }

    func register(_ ext: any BrowserExtension) {
        guard !installedExtensions.contains(where: { $0.id == ext.id }) else { return }
        installedExtensions.append(ext)
    }

    func unregister(_ ext: any BrowserExtension) {
        installedExtensions.removeAll { $0.id == ext.id }
        enabledExtensionIDs.remove(ext.id)
        persist()
    }

    func isEnabled(_ ext: any BrowserExtension) -> Bool {
        enabledExtensionIDs.contains(ext.id)
    }

    func setEnabled(_ enabled: Bool, for ext: any BrowserExtension) {
        if enabled {
            enabledExtensionIDs.insert(ext.id)
        } else {
            enabledExtensionIDs.remove(ext.id)
        }
        persist()
    }

    /// Применяет все включённые расширения к переданному WKWebView (вызывается WebViewController при настройке).
    func applyEnabledExtensions(to configuration: WKWebViewConfiguration) {
        for ext in installedExtensions where isEnabled(ext) {
            ext.inject(into: configuration)
        }
    }

    /// Уведомляет расширения о том, что страница закончила загрузку (для пост-обработки, напр. RSS-детект).
    func notifyPageDidFinishLoading(webView: WKWebView, url: URL?) {
        for ext in installedExtensions where isEnabled(ext) {
            ext.onPageFinishedLoading(webView: webView, url: url)
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(enabledExtensionIDs), forKey: enabledKey)
    }
}
