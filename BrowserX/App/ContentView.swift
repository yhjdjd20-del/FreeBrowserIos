// Путь: BrowserX/App/ContentView.swift
import SwiftUI

struct ContentView: View {

    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var extensionManager: ExtensionManager
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var passwordManager: PasswordManager

    @State private var isChatSidebarPresented = false
    @State private var isDownloadsPresented = false
    @State private var isSettingsPresented = false
    @State private var isReaderModePresented = false

    var body: some View {
        NavigationSplitView {
            TabSidebarStripView()
                .environmentObject(tabManager)
        } detail: {
            VStack(spacing: 0) {
                AddressBar(
                    onOpenChat: { isChatSidebarPresented.toggle() },
                    onOpenDownloads: { isDownloadsPresented.toggle() },
                    onOpenSettings: { isSettingsPresented.toggle() },
                    onOpenReaderMode: { isReaderModePresented.toggle() }
                )
                .environmentObject(tabManager)
                .environmentObject(userSettings)

                Divider()

                ZStack {
                    if let activeTab = tabManager.activeTab {
                        WebView(tab: activeTab)
                            .environmentObject(downloadManager)
                            .environmentObject(extensionManager)
                            .id(activeTab.id)
                    } else {
                        EmptyStateView {
                            tabManager.openNewTab(url: userSettings.homePageURL)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isChatSidebarPresented) {
            ChatSidebar(currentURL: tabManager.activeTab?.url)
        }
        .sheet(isPresented: $isDownloadsPresented) {
            DownloadListView()
                .environmentObject(downloadManager)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environmentObject(userSettings)
                .environmentObject(extensionManager)
                .environmentObject(passwordManager)
        }
        .sheet(isPresented: $isReaderModePresented) {
            if let activeTab = tabManager.activeTab {
                ReaderModeView(tab: activeTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .browserXNewTabRequested)) { _ in
            tabManager.openNewTab(url: userSettings.homePageURL)
        }
    }
}

/// Простое пустое состояние, когда нет открытых вкладок.
private struct EmptyStateView: View {
    let onNewTab: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Нет открытых вкладок")
                .font(.title3.bold())
            Button("Открыть новую вкладку", action: onNewTab)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
        .environmentObject(TabManager())
        .environmentObject(DownloadManager())
        .environmentObject(ExtensionManager())
        .environmentObject(UserSettings())
        .environmentObject(PasswordManager())
}
