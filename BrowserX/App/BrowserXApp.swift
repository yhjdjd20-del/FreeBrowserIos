// Путь: BrowserX/App/BrowserXApp.swift
import SwiftUI

@main
struct BrowserXApp: App {

    @StateObject private var tabManager = TabManager()
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var extensionManager = ExtensionManager()
    @StateObject private var userSettings = UserSettings()
    @StateObject private var passwordManager = PasswordManager()

    init() {
        // Регистрируем встроенные расширения при старте приложения.
        // ExtensionManager сам подгружает список по умолчанию через registerBuiltInExtensions().
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabManager)
                .environmentObject(downloadManager)
                .environmentObject(extensionManager)
                .environmentObject(userSettings)
                .environmentObject(passwordManager)
                .task {
                    extensionManager.registerBuiltInExtensions()
                    if tabManager.tabs.isEmpty {
                        tabManager.openNewTab(url: userSettings.homePageURL)
                    }
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новая вкладка") {
                    NotificationCenter.default.post(name: .browserXNewTabRequested, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
        #endif
    }
}

extension Notification.Name {
    static let browserXNewTabRequested = Notification.Name("browserXNewTabRequested")
    static let browserXCloseTabRequested = Notification.Name("browserXCloseTabRequested")
}
