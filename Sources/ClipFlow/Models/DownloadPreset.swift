import Foundation

public enum DownloadTargetCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case video = "Video"
    case audio = "Audio"
    case customStream = "Raw Stream"

    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        case .customStream: return "slider.horizontal.3"
        }
    }
}

public enum VideoContainerFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case mp4 = "mp4"
    case mkv = "mkv"
    case webm = "webm"
    case mov = "mov"

    public var id: String { rawValue }
    public var displayName: String { rawValue.uppercased() }
}

public enum AudioContainerFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case mp3 = "mp3"
    case m4a = "m4a"
    case flac = "flac"
    case wav = "wav"
    case opus = "opus"

    public var id: String { rawValue }
    public var displayName: String { rawValue.uppercased() }
}

public enum QualityPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case best = "Best Available (Max Quality)"
    case uhd4k = "4K Ultra HD (2160p)"
    case qhd1440 = "2K Quad HD (1440p)"
    case fhd1080 = "1080p Full HD"
    case hd720 = "720p HD"
    case sd480 = "480p SD"
    case sd360 = "360p Data Saver"

    public var id: String { rawValue }

    public var maxHeight: Int? {
        switch self {
        case .best: return nil
        case .uhd4k: return 2160
        case .qhd1440: return 1440
        case .fhd1080: return 1080
        case .hd720: return 720
        case .sd480: return 480
        case .sd360: return 360
        }
    }

    public var badgeLabel: String {
        switch self {
        case .best: return "MAX"
        case .uhd4k: return "4K"
        case .qhd1440: return "2K"
        case .fhd1080: return "1080p"
        case .hd720: return "720p"
        case .sd480: return "480p"
        case .sd360: return "360p"
        }
    }

    /// Generates yt-dlp format selector string
    public func ytDlpFormatSelector(container: VideoContainerFormat) -> String {
        if let h = maxHeight {
            // Pick best video with height <= h, plus best audio, fallback to best
            return "bestvideo[height<=\(h)]+bestaudio/best[height<=\(h)]/best"
        } else {
            return "bestvideo+bestaudio/best"
        }
    }
}
