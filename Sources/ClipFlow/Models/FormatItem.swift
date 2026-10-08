import Foundation

public struct FormatItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String { formatId }
    public let formatId: String
    public let ext: String
    public let formatNote: String?
    public let resolution: String?
    public let width: Int?
    public let height: Int?
    public let fps: Double?
    public let vcodec: String?
    public let acodec: String?
    public let filesize: Int64?
    public let filesizeApprox: Int64?
    public let tbr: Double?
    public let vbr: Double?
    public let abr: Double?
    public let dynamicRange: String?
    public let formatDescription: String?

    public init(
        formatId: String,
        ext: String,
        formatNote: String? = nil,
        resolution: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        fps: Double? = nil,
        vcodec: String? = nil,
        acodec: String? = nil,
        filesize: Int64? = nil,
        filesizeApprox: Int64? = nil,
        tbr: Double? = nil,
        vbr: Double? = nil,
        abr: Double? = nil,
        dynamicRange: String? = nil,
        formatDescription: String? = nil
    ) {
        self.formatId = formatId
        self.ext = ext
        self.formatNote = formatNote
        self.resolution = resolution
        self.width = width
        self.height = height
        self.fps = fps
        self.vcodec = vcodec
        self.acodec = acodec
        self.filesize = filesize
        self.filesizeApprox = filesizeApprox
        self.tbr = tbr
        self.vbr = vbr
        self.abr = abr
        self.dynamicRange = dynamicRange
        self.formatDescription = formatDescription
    }

    public var isStoryboard: Bool {
        ext == "mhtml" || (formatNote?.lowercased().contains("storyboard") ?? false)
    }

    public var isAudioOnly: Bool {
        let hasNoVideo = vcodec == nil || vcodec == "none"
        let hasAudio = acodec != nil && acodec != "none"
        return hasNoVideo && hasAudio
    }

    public var isVideoOnly: Bool {
        let hasVideo = vcodec != nil && vcodec != "none"
        let hasNoAudio = acodec == nil || acodec == "none"
        return hasVideo && hasNoAudio
    }

    public var isMuxedVideoAndAudio: Bool {
        let hasVideo = vcodec != nil && vcodec != "none"
        let hasAudio = acodec != nil && acodec != "none"
        return hasVideo && hasAudio
    }

    public var streamType: StreamType {
        if isAudioOnly { return .audioOnly }
        if isVideoOnly { return .videoOnly }
        if isMuxedVideoAndAudio { return .videoWithAudio }
        return .other
    }

    public enum StreamType: String, CaseIterable, Identifiable, Codable, Sendable {
        case videoWithAudio = "Muxed (Video + Audio)"
        case videoOnly = "Video Only"
        case audioOnly = "Audio Only"
        case other = "Other"

        public var id: String { rawValue }
    }

    public var qualityLabel: String {
        if let h = height {
            if h >= 2160 { return "4K Ultra HD (\(h)p)" }
            if h >= 1440 { return "2K QHD (\(h)p)" }
            if h >= 1080 { return "1080p Full HD" }
            if h >= 720 { return "720p HD" }
            if h >= 480 { return "480p" }
            if h >= 360 { return "360p" }
            return "\(h)p"
        }
        if isAudioOnly {
            if let abr = abr {
                return "\(Int(abr)) kbps Audio"
            }
            if let note = formatNote, !note.isEmpty {
                return "\(note) Audio"
            }
            return "Audio (\(ext.uppercased()))"
        }
        return formatNote ?? resolution ?? ext.uppercased()
    }

    public var effectiveFilesize: Int64? {
        filesize ?? filesizeApprox
    }

    public var formattedSize: String {
        guard let bytes = effectiveFilesize, bytes > 0 else {
            return "Unknown Size"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public var codecSummary: String {
        if isAudioOnly {
            let codec = acodec?.components(separatedBy: ".").first ?? (acodec ?? "Audio")
            let bitrate = abr.map { "\(Int($0))k" } ?? ""
            return [codec, bitrate].filter { !$0.isEmpty }.joined(separator: " • ")
        } else {
            var parts: [String] = []
            if let v = vcodec?.components(separatedBy: ".").first, v != "none" {
                parts.append(v)
            }
            if let f = fps, f > 0 {
                parts.append("\(Int(f))fps")
            }
            if let hdr = dynamicRange, hdr.contains("HDR") {
                parts.append("HDR")
            }
            if isMuxedVideoAndAudio, let a = acodec?.components(separatedBy: ".").first, a != "none" {
                parts.append("Audio: \(a)")
            } else if isVideoOnly {
                parts.append("Video Only")
            }
            return parts.joined(separator: " • ")
        }
    }
}
