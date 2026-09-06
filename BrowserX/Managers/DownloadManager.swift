// Путь: BrowserX/Managers/DownloadManager.swift
import Foundation
import Combine

/// Управляет загрузками файлов: старт, пауза, возобновление, отмена, сохранение в Documents/Downloads.
@MainActor
final class DownloadManager: NSObject, ObservableObject {

    @Published private(set) var downloads: [DownloadItem] = []

    private var session: URLSession!
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private let persistenceKey = "downloadManager.items"

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        loadPersistedItems()
    }

    // MARK: - Публичное API

    func startDownload(from url: URL, suggestedFileName: String? = nil) {
        let fileName = suggestedFileName ?? url.lastPathComponent
        let destination = "Downloads/\(UUID().uuidString)_\(fileName)"

        var item = DownloadItem(fileName: fileName, sourceURL: url, destinationPath: destination)
        item.state = .downloading
        downloads.append(item)
        persist()

        let task = session.downloadTask(with: url)
        tasks[item.id] = task
        taskToItemID[task.taskIdentifier] = item.id
        task.resume()
    }

    func pause(_ item: DownloadItem) {
        guard let task = tasks[item.id] else { return }
        task.cancel { [weak self] resumeData in
            Task { @MainActor in
                self?.updateItem(item.id) { $0.state = .paused; $0.resumeData = resumeData }
                self?.tasks[item.id] = nil
            }
        }
    }

    func resume(_ item: DownloadItem) {
        guard item.state == .paused else { return }
        let task: URLSessionDownloadTask
        if let resumeData = item.resumeData {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: item.sourceURL)
        }
        tasks[item.id] = task
        taskToItemID[task.taskIdentifier] = item.id
        updateItem(item.id) { $0.state = .downloading }
        task.resume()
    }

    func cancel(_ item: DownloadItem) {
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        updateItem(item.id) { $0.state = .cancelled }
    }

    func delete(_ item: DownloadItem) {
        let fileURL = downloadsDirectory.appendingPathComponent(item.destinationPath)
        try? FileManager.default.removeItem(at: fileURL)
        downloads.removeAll { $0.id == item.id }
        persist()
    }

    func fileURL(for item: DownloadItem) -> URL {
        downloadsDirectory.appendingPathComponent(item.destinationPath)
    }

    // MARK: - Хранилище

    private var downloadsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return documents
    }

    private var taskToItemID: [Int: UUID] = [:]

    private func updateItem(_ id: UUID, _ mutate: (inout DownloadItem) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        mutate(&downloads[index])
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadPersistedItems() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        // Все активные загрузки при рестарте приложения помечаем как paused, чтобы пользователь мог возобновить.
        downloads = items.map { item in
            var copy = item
            if copy.state == .downloading || copy.state == .pending {
                copy.state = .paused
            }
            return copy
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let itemID = self.taskToItemID[taskID],
                  let index = self.downloads.firstIndex(where: { $0.id == itemID }) else { return }

            let item = self.downloads[index]
            let destination = self.downloadsDirectory.appendingPathComponent(item.destinationPath)

            try? FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: destination)

            do {
                try FileManager.default.copyItem(at: location, to: destination)
                self.updateItem(itemID) { $0.state = .completed; $0.completedAt = Date(); $0.receivedBytes = $0.totalBytes }
            } catch {
                self.updateItem(itemID) { $0.state = .failed }
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let itemID = self.taskToItemID[taskID] else { return }
            self.updateItem(itemID) {
                $0.receivedBytes = totalBytesWritten
                $0.totalBytes = totalBytesExpectedToWrite
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskID = task.taskIdentifier
        Task { @MainActor in
            guard let itemID = self.taskToItemID[taskID] else { return }
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                // Отмена — уже обработана в pause()/cancel()
                return
            }
            self.updateItem(itemID) { $0.state = .failed }
        }
    }
}
