// Путь: BrowserX/Models/DownloadItem.swift
import Foundation

/// Статус загрузки файла.
enum DownloadState: String, Codable {
    case pending
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

/// Модель одной загрузки. Хранится в DownloadManager и персистится через FileManager/UserDefaults.
struct DownloadItem: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var sourceURL: URL
    var destinationPath: String // относительный путь внутри Documents/Downloads
    var totalBytes: Int64
    var receivedBytes: Int64
    var state: DownloadState
    var createdAt: Date
    var completedAt: Date?
    var resumeData: Data? // для возобновления через URLSessionDownloadTask

    init(
        id: UUID = UUID(),
        fileName: String,
        sourceURL: URL,
        destinationPath: String,
        totalBytes: Int64 = 0,
        receivedBytes: Int64 = 0,
        state: DownloadState = .pending,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        resumeData: Data? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.destinationPath = destinationPath
        self.totalBytes = totalBytes
        self.receivedBytes = receivedBytes
        self.state = state
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.resumeData = resumeData
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(receivedBytes) / Double(totalBytes)
    }

    var isActive: Bool {
        state == .downloading || state == .pending
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}
