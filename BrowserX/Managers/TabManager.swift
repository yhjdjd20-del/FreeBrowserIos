// Путь: BrowserX/Managers/TabManager.swift
import Foundation
import Combine
import SwiftUI

/// Управляет коллекцией вкладок: открытие, закрытие, переупорядочивание (drag & drop),
/// переключение активной вкладки, восстановление сессии.
@MainActor
final class TabManager: ObservableObject {

    @Published private(set) var tabs: [Tab] = []
    @Published var activeTabID: Tab.ID?

    private let sessionStore = TabSessionStore()

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    init() {
        restoreSession()
    }

    // MARK: - Открытие / закрытие

    @discardableResult
    func openNewTab(url: URL, isPrivate: Bool = false, makeActive: Bool = true) -> Tab {
        let tab = Tab(url: url, isPrivate: isPrivate)
        tabs.append(tab)
        if makeActive {
            activeTabID = tab.id
        }
        persistSession()
        return tab
    }

    func closeTab(_ tab: Tab) {
        guard let index = tabs.firstIndex(of: tab) else { return }
        let wasActive = activeTabID == tab.id
        tabs.remove(at: index)

        if wasActive {
            if tabs.isEmpty {
                activeTabID = nil
            } else {
                let newIndex = min(index, tabs.count - 1)
                activeTabID = tabs[newIndex].id
            }
        }
        persistSession()
    }

    func closeAllTabs(keepingPinned: Bool = false) {
        tabs.removeAll()
        activeTabID = nil
        persistSession()
    }

    func selectTab(_ tab: Tab) {
        activeTabID = tab.id
    }

    // MARK: - Перетаскивание (Drag & Drop) для горизонтальной полосы вкладок

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        persistSession()
    }

    func moveTab(draggedID: Tab.ID, ontoID targetID: Tab.ID) {
        guard let fromIndex = tabs.firstIndex(where: { $0.id == draggedID }),
              let toIndex = tabs.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else { return }
        let tab = tabs.remove(at: fromIndex)
        tabs.insert(tab, at: toIndex)
        persistSession()
    }

    // MARK: - Навигация активной вкладки

    func goBack() { activeTab?.webViewController.webView?.goBack() }
    func goForward() { activeTab?.webViewController.webView?.goForward() }
    func reload() { activeTab?.webViewController.webView?.reload() }
    func stopLoading() { activeTab?.webViewController.webView?.stopLoading() }

    func load(url: URL) {
        guard let tab = activeTab else {
            openNewTab(url: url)
            return
        }
        tab.webViewController.load(url: url)
    }

    // MARK: - Снапшоты вкладок (превью для сетки вкладок)

    func captureSnapshot(for tab: Tab) {
        tab.webViewController.captureSnapshot { data in
            Task { @MainActor in
                tab.snapshot = data
            }
        }
    }

    // MARK: - Персистентность сессии

    private func persistSession() {
        let entries = tabs.map { TabSessionStore.Entry(url: $0.url, isPrivate: $0.isPrivate) }
        sessionStore.save(entries: entries, activeIndex: tabs.firstIndex { $0.id == activeTabID })
    }

    private func restoreSession() {
        let (entries, activeIndex) = sessionStore.load()
        guard !entries.isEmpty else { return }
        for entry in entries where !entry.isPrivate {
            openNewTab(url: entry.url, isPrivate: entry.isPrivate, makeActive: false)
        }
        if let activeIndex, tabs.indices.contains(activeIndex) {
            activeTabID = tabs[activeIndex].id
        } else {
            activeTabID = tabs.first?.id
        }
    }
}

/// Простое хранилище последней сессии вкладок в UserDefaults (без приватных вкладок).
private struct TabSessionStore {
    struct Entry: Codable {
        let url: URL
        let isPrivate: Bool
    }

    private let key = "tabManager.session"

    func save(entries: [Entry], activeIndex: Int?) {
        let payload = SessionPayload(entries: entries, activeIndex: activeIndex)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> ([Entry], Int?) {
        guard let data = UserDefaults.standard.data(forKey: key),
              let payload = try? JSONDecoder().decode(SessionPayload.self, from: data) else {
            return ([], nil)
        }
        return (payload.entries, payload.activeIndex)
    }

    private struct SessionPayload: Codable {
        let entries: [Entry]
        let activeIndex: Int?
    }
}
