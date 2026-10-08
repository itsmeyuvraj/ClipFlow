import Foundation

public struct VideoInfo: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let description: String?
    public let thumbnail: String?
    public let duration: Double?
    public let channel: String?
    public let uploader: String?
    public let uploaderUrl: String?
    public let viewCount: Int?
    public let uploadDate: String?
    public let webpageUrl: String
    public let formats: [FormatItem]

    public init(
        id: String,
        title: String,
        description: String? = nil,
        thumbnail: String? = nil,
        duration: Double? = nil,
        channel: String? = nil,
        uploader: String? = nil,
        uploaderUrl: String? = nil,
        viewCount: Int? = nil,
        uploadDate: String? = nil,
        webpageUrl: String,
        formats: [FormatItem] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.thumbnail = thumbnail
        self.duration = duration
        self.channel = channel
        self.uploader = uploader
        self.uploaderUrl = uploaderUrl
        self.viewCount = viewCount
        self.uploadDate = uploadDate
        self.webpageUrl = webpageUrl
        self.formats = formats
    }

    public var authorName: String {
        channel ?? uploader ?? "Unknown Channel"
    }

    public var formattedDuration: String {
        guard let dur = duration, dur > 0 else { return "--:--" }
        let totalSeconds = Int(dur)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    public var formattedViewCount: String {
        guard let count = viewCount else { return "" }
        if count >= 1_000_000_000 {
            return String(format: "%.1fB views", Double(count) / 1_000_000_000.0)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM views", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK views", Double(count) / 1_000.0)
        } else {
            return "\(count) views"
        }
    }

    public var formattedUploadDate: String {
        guard let dateStr = uploadDate, dateStr.count == 8 else { return "" }
        let year = String(dateStr.prefix(4))
        let month = String(dateStr.dropFirst(4).prefix(2))
        let day = String(dateStr.suffix(2))
        return "\(year)-\(month)-\(day)"
    }

    /// Clean valid formats (excluding storyboard cards)
    public var validFormats: [FormatItem] {
        formats.filter { !$0.isStoryboard }
    }

    /// Video streams (both muxed and video-only) sorted by resolution descending
    public var videoFormats: [FormatItem] {
        validFormats
            .filter { !$0.isAudioOnly }
            .sorted { (f1, f2) -> Bool in
                let h1 = f1.height ?? 0
                let h2 = f2.height ?? 0
                if h1 != h2 { return h1 > h2 }
                let tbr1 = f1.tbr ?? 0
                let tbr2 = f2.tbr ?? 0
                return tbr1 > tbr2
            }
    }

    /// Audio-only streams sorted by audio bitrate descending
    public var audioFormats: [FormatItem] {
        validFormats
            .filter { $0.isAudioOnly }
            .sorted { (f1, f2) -> Bool in
                let abr1 = f1.abr ?? 0
                let abr2 = f2.abr ?? 0
                return abr1 > abr2
            }
    }

    /// Unique resolution heights available (e.g. [2160, 1440, 1080, 720, 480, 360])
    public var availableResolutions: [Int] {
        let heights = videoFormats.compactMap { $0.height }
        return Array(Set(heights)).sorted(by: >)
    }

    public static func parseFromYtDlpJSON(_ data: Data) throws -> VideoInfo {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        let id = json["id"] as? String ?? UUID().uuidString
        let title = json["title"] as? String ?? "Untitled Video"
        let description = json["description"] as? String
        let thumbnail = json["thumbnail"] as? String
        let duration = json["duration"] as? Double ?? (json["duration"] as? Int).map { Double($0) }
        let channel = json["channel"] as? String
        let uploader = json["uploader"] as? String
        let uploaderUrl = json["uploader_url"] as? String
        let viewCount = json["view_count"] as? Int
        let uploadDate = json["upload_date"] as? String
        let webpageUrl = json["webpage_url"] as? String ?? "https://youtube.com/watch?v=\(id)"
        
        var formatItems: [FormatItem] = []
        if let formatsRaw = json["formats"] as? [[String: Any]] {
            for raw in formatsRaw {
                guard let formatId = raw["format_id"] as? String else { continue }
                let ext = raw["ext"] as? String ?? ""
                let formatNote = raw["format_note"] as? String
                let resolution = raw["resolution"] as? String
                let width = raw["width"] as? Int
                let height = raw["height"] as? Int
                let fps = raw["fps"] as? Double ?? (raw["fps"] as? Int).map { Double($0) }
                let vcodec = raw["vcodec"] as? String
                let acodec = raw["acodec"] as? String
                let filesize = (raw["filesize"] as? Int64) ?? (raw["filesize"] as? Int).map { Int64($0) }
                let filesizeApprox = (raw["filesize_approx"] as? Int64) ?? (raw["filesize_approx"] as? Int).map { Int64($0) }
                let tbr = raw["tbr"] as? Double ?? (raw["tbr"] as? Int).map { Double($0) }
                let vbr = raw["vbr"] as? Double ?? (raw["vbr"] as? Int).map { Double($0) }
                let abr = raw["abr"] as? Double ?? (raw["abr"] as? Int).map { Double($0) }
                let dynamicRange = raw["dynamic_range"] as? String
                let formatDescription = raw["format"] as? String
                
                let item = FormatItem(
                    formatId: formatId,
                    ext: ext,
                    formatNote: formatNote,
                    resolution: resolution,
                    width: width,
                    height: height,
                    fps: fps,
                    vcodec: vcodec,
                    acodec: acodec,
                    filesize: filesize,
                    filesizeApprox: filesizeApprox,
                    tbr: tbr,
                    vbr: vbr,
                    abr: abr,
                    dynamicRange: dynamicRange,
                    formatDescription: formatDescription
                )
                formatItems.append(item)
            }
        }
        
        return VideoInfo(
            id: id,
            title: title,
            description: description,
            thumbnail: thumbnail,
            duration: duration,
            channel: channel,
            uploader: uploader,
            uploaderUrl: uploaderUrl,
            viewCount: viewCount,
            uploadDate: uploadDate,
            webpageUrl: webpageUrl,
            formats: formatItems
        )
    }
}
