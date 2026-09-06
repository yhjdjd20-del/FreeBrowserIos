// Путь: BrowserX/Models/UserSettings.swift
import Foundation
import Combine
import SwiftUI

/// Глобальные настройки пользователя. ObservableObject + AppStorage-подобное хранение
/// через UserDefaults, чтобы значения переживали перезапуск приложения.
@MainActor
final class UserSettings: ObservableObject {

    private enum Keys {
        static let homePage = "settings.homePage"
        static let searchEngine = "settings.searchEngine"
        static let darkMode = "settings.darkMode"
        static let adBlockEnabled = "settings.adBlockEnabled"
        static let doNotTrack = "settings.doNotTrack"
        static let claudeModel = "settings.claudeModel"
        static let readerModeAutoDetect = "settings.readerModeAutoDetect"
        static let syncEnabled = "settings.syncEnabled"
        static let faceIDForPasswords = "settings.faceIDForPasswords"
    }

    @Published var homePageURL: URL {
        didSet { UserDefaults.standard.set(homePageURL.absoluteString, forKey: Keys.homePage) }
    }

    @Published var searchEngine: SearchEngine {
        didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: Keys.searchEngine) }
    }

    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: Keys.darkMode) }
    }

    @Published var isAdBlockEnabled: Bool {
        didSet { UserDefaults.standard.set(isAdBlockEnabled, forKey: Keys.adBlockEnabled) }
    }

    @Published var doNotTrack: Bool {
        didSet { UserDefaults.standard.set(doNotTrack, forKey: Keys.doNotTrack) }
    }

    @Published var claudeModel: String {
        didSet { UserDefaults.standard.set(claudeModel, forKey: Keys.claudeModel) }
    }

    @Published var readerModeAutoDetect: Bool {
        didSet { UserDefaults.standard.set(readerModeAutoDetect, forKey: Keys.readerModeAutoDetect) }
    }

    @Published var isSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(isSyncEnabled, forKey: Keys.syncEnabled) }
    }

    @Published var faceIDForPasswordsEnabled: Bool {
        didSet { UserDefaults.standard.set(faceIDForPasswordsEnabled, forKey: Keys.faceIDForPasswords) }
    }

    enum SearchEngine: String, CaseIterable, Identifiable {
        case google, duckDuckGo, bing, ecosia

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .google: return "Google"
            case .duckDuckGo: return "DuckDuckGo"
            case .bing: return "Bing"
            case .ecosia: return "Ecosia"
            }
        }

        func searchURL(for query: String) -> URL {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            switch self {
            case .google: return URL(string: "https://www.google.com/search?q=\(encoded)")!
            case .duckDuckGo: return URL(string: "https://duckduckgo.com/?q=\(encoded)")!
            case .bing: return URL(string: "https://www.bing.com/search?q=\(encoded)")!
            case .ecosia: return URL(string: "https://www.ecosia.org/search?q=\(encoded)")!
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        self.homePageURL = URL(string: defaults.string(forKey: Keys.homePage) ?? "https://www.apple.com") ?? URL(string: "https://www.apple.com")!
        self.searchEngine = SearchEngine(rawValue: defaults.string(forKey: Keys.searchEngine) ?? "") ?? .google
        self.isDarkMode = defaults.bool(forKey: Keys.darkMode)
        self.isAdBlockEnabled = defaults.object(forKey: Keys.adBlockEnabled) as? Bool ?? true
        self.doNotTrack = defaults.bool(forKey: Keys.doNotTrack)
        self.claudeModel = defaults.string(forKey: Keys.claudeModel) ?? "claude-sonnet-4-6"
        self.readerModeAutoDetect = defaults.object(forKey: Keys.readerModeAutoDetect) as? Bool ?? true
        self.isSyncEnabled = defaults.bool(forKey: Keys.syncEnabled)
        self.faceIDForPasswordsEnabled = defaults.object(forKey: Keys.faceIDForPasswords) as? Bool ?? true
    }
}
