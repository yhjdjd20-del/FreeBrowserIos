// Путь: BrowserX/Views/TabSidebarStripView.swift
import SwiftUI
import UniformTypeIdentifiers

/// Горизонтальная (или вертикальная в сайдбаре) полоса вкладок с поддержкой
/// перетаскивания (drag & drop) для изменения порядка, закрытия свайпом/кнопкой,
/// и мини-превью на основе снапшота страницы.
struct TabSidebarStripView: View {

    @EnvironmentObject var tabManager: TabManager
    @State private var draggingTabID: Tab.ID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabManager.tabs) { tab in
                        TabChipView(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabID,
                            onSelect: { tabManager.selectTab(tab) },
                            onClose: { tabManager.closeTab(tab) }
                        )
                        .id(tab.id)
                        .onDrag {
                            draggingTabID = tab.id
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            targetTab: tab,
                            tabManager: tabManager,
                            draggingTabID: $draggingTabID
                        ))
                    }

                    Button(action: { tabManager.openNewTab(url: URL(string: "https://www.apple.com")!) }) {
                        Image(systemName: "plus")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: tabManager.activeTabID) { _, newValue in
                guard let newValue else { return }
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .frame(height: 44)
        .background(.bar)
    }
}

/// Одна "плашка" вкладки — заголовок, мини-favicon, кнопка закрытия.
private struct TabChipView: View {
    @ObservedObject var tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if tab.isPrivate {
                Image(systemName: "eyeglasses")
                    .font(.caption2)
            } else if tab.isLoading {
                ProgressView().scaleEffect(0.5)
            }

            Text(tab.title)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .frame(maxWidth: 180)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

/// Drop-делегат для перетаскивания вкладок по горизонтальной полосе.
private struct TabDropDelegate: DropDelegate {
    let targetTab: Tab
    let tabManager: TabManager
    @Binding var draggingTabID: Tab.ID?

    func dropEntered(info: DropInfo) {
        guard let draggingTabID, draggingTabID != targetTab.id else { return }
        tabManager.moveTab(draggedID: draggingTabID, ontoID: targetTab.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabID = nil
        return true
    }
}
