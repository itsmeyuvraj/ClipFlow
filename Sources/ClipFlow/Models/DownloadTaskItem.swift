import Foundation

public enum DownloadStatus: Hashable, Codable, Sendable {
    case pending
    case downloading(progress: Double, speed: String, eta: String, downloadedBytes: Int64, totalBytes: Int64)
    case processing(stage: String)
    case completed(outputUrlString: String)
    case failed(message: String)
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }

    public var statusDescription: String {
        switch self {
        case .pending:
            return "Queued"
        case .downloading(let progress, let speed, let eta, _, _):
            let pct = Int(progress * 100)
            if !speed.isEmpty && !eta.isEmpty {
                return "\(pct)% • \(speed) • ETA \(eta)"
            } else if !speed.isEmpty {
                return "\(pct)% • \(speed)"
            }
            return "Downloading \(pct)%"
        case .processing(let stage):
            return stage
        case .completed:
            return "Completed"
        case .failed(let message):
            return "Failed: \(message)"
        case .cancelled:
            return "Cancelled"
        }
    }
}

public struct DownloadTaskItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let videoInfo: VideoInfo
    public let category: DownloadTargetCategory
    public let videoPreset: QualityPreset?
    public let videoContainer: VideoContainerFormat
    public let audioContainer: AudioContainerFormat
    public let selectedFormatId: String?
    public let destinationFolder: String
    public let embedThumbnail: Bool
    public let embedSubtitles: Bool
    public let embedChapters: Bool
    public var status: DownloadStatus
    public var progress: Double
    public var speed: String
    public var eta: String
    public var downloadedBytes: Int64
    public var totalBytes: Int64
    public var downloadedFilePath: String?
    public let createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        videoInfo: VideoInfo,
        category: DownloadTargetCategory = .video,
        videoPreset: QualityPreset? = .best,
        videoContainer: VideoContainerFormat = .mp4,
        audioContainer: AudioContainerFormat = .mp3,
        selectedFormatId: String? = nil,
        destinationFolder: String,
        embedThumbnail: Bool = true,
        embedSubtitles: Bool = false,
        embedChapters: Bool = true,
        status: DownloadStatus = .pending,
        progress: Double = 0.0,
        speed: String = "",
        eta: String = "",
        downloadedBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        downloadedFilePath: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.videoInfo = videoInfo
        self.category = category
        self.videoPreset = videoPreset
        self.videoContainer = videoContainer
        self.audioContainer = audioContainer
        self.selectedFormatId = selectedFormatId
        self.destinationFolder = destinationFolder
        self.embedThumbnail = embedThumbnail
        self.embedSubtitles = embedSubtitles
        self.embedChapters = embedChapters
        self.status = status
        self.progress = progress
        self.speed = speed
        self.eta = eta
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.downloadedFilePath = downloadedFilePath
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public var summaryLabel: String {
        switch category {
        case .video:
            return "\(videoPreset?.badgeLabel ?? "VIDEO") • \(videoContainer.displayName)"
        case .audio:
            return "AUDIO • \(audioContainer.displayName)"
        case .customStream:
            return "STREAM #\(selectedFormatId ?? "CUSTOM")"
        }
    }
}
