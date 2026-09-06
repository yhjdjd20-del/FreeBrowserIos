// Путь: BrowserX/Views/DownloadListView.swift
import SwiftUI

/// Экран менеджера загрузок: список активных и завершённых файлов, управление
/// паузой/возобновлением/отменой, открытие/удаление скачанных файлов.
struct DownloadListView: View {

    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if downloadManager.downloads.isEmpty {
                    ContentUnavailableView(
                        "Нет загрузок",
                        systemImage: "arrow.down.circle",
                        description: Text("Файлы, скачанные из браузера, появятся здесь")
                    )
                } else {
                    ForEach(downloadManager.downloads.sorted(by: { $0.createdAt > $1.createdAt })) { item in
                        DownloadRow(item: item)
                    }
                }
            }
            .navigationTitle("Загрузки")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

private struct DownloadRow: View {
    @EnvironmentObject var downloadManager: DownloadManager
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actionButton
            }

            if item.state == .downloading || item.state == .paused {
                ProgressView(value: item.progress)
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button(role: .destructive) {
                downloadManager.delete(item)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private var iconName: String {
        switch item.state {
        case .completed: return "doc.fill"
        case .failed, .cancelled: return "exclamationmark.triangle"
        default: return "arrow.down.circle"
        }
    }

    private var statusText: String {
        switch item.state {
        case .pending: return "В очереди"
        case .downloading: return "\(item.formattedSize) · \(Int(item.progress * 100))%"
        case .paused: return "Приостановлено · \(Int(item.progress * 100))%"
        case .completed: return "Готово · \(item.formattedSize)"
        case .failed: return "Ошибка загрузки"
        case .cancelled: return "Отменено"
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.state {
        case .downloading:
            Button(action: { downloadManager.pause(item) }) {
                Image(systemName: "pause.circle")
            }
        case .paused, .failed:
            Button(action: { downloadManager.resume(item) }) {
                Image(systemName: "arrow.clockwise.circle")
            }
        case .completed:
            ShareLink(item: downloadManager.fileURL(for: item)) {
                Image(systemName: "square.and.arrow.up")
            }
        case .pending, .cancelled:
            EmptyView()
        }
    }
}
