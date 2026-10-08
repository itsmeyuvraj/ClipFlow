import Foundation

public struct AppAnalysisError: Identifiable, Equatable, Sendable {
    public var id: String { title + message }
    public let title: String
    public let message: String
    public let suggestion: String?
    public let iconName: String

    public init(
        title: String,
        message: String,
        suggestion: String? = nil,
        iconName: String = "exclamationmark.triangle.fill"
    ) {
        self.title = title
        self.message = message
        self.suggestion = suggestion
        self.iconName = iconName
    }
}

public enum AnalysisErrorParser {
    public static func validateUrl(_ urlString: String) -> AppAnalysisError? {
        let clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return AppAnalysisError(
                title: "Empty URL",
                message: "No link was entered.",
                suggestion: "Paste a YouTube video or Shorts link in the input field above.",
                iconName: "link.badge.plus"
            )
        }

        // Check scheme
        guard let url = URL(string: clean), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return AppAnalysisError(
                title: "Invalid Web Link",
                message: "\"\(clean)\" is not recognized as a valid web link.",
                suggestion: "Please enter a full URL starting with https:// (e.g., https://www.youtube.com/watch?v=...)",
                iconName: "exclamationmark.link"
            )
        }

        // Check host
        guard let host = url.host?.lowercased() else {
            return AppAnalysisError(
                title: "Incomplete Link",
                message: "The URL is missing a web domain.",
                suggestion: "Copy the link directly from your browser's address bar or the YouTube Share menu.",
                iconName: "globe"
            )
        }

        let isYouTube = host.contains("youtube.com") || host.contains("youtu.be")
        if !isYouTube {
            return AppAnalysisError(
                title: "Non-YouTube Link",
                message: "The link is from \"\(host)\". ClipFlow is optimized specifically for YouTube videos, Shorts, and Music.",
                suggestion: "Please provide a link from youtube.com or youtu.be.",
                iconName: "play.slash"
            )
        }

        // Check missing ID in short links
        if host.contains("youtu.be") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.isEmpty {
                return AppAnalysisError(
                    title: "Incomplete YouTube Link",
                    message: "The youtu.be link does not contain a video ID.",
                    suggestion: "Make sure you copied the complete share link (e.g., https://youtu.be/dQw4w9WgXcQ).",
                    iconName: "link"
                )
            }
        } else if host.contains("youtube.com") {
            if url.path.contains("/watch") {
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let v = queryItems?.first(where: { $0.name == "v" })?.value
                if v == nil || v?.isEmpty == true {
                    return AppAnalysisError(
                        title: "Missing Video ID",
                        message: "The YouTube watch link is missing the video identifier (\"?v=\").",
                        suggestion: "Copy the full link directly from YouTube.",
                        iconName: "questionmark.video"
                    )
                }
            } else if !url.path.contains("/shorts/") && !url.path.contains("/live/") && !url.path.contains("/v/") {
                return AppAnalysisError(
                    title: "Not a Video Link",
                    message: "This link points to a YouTube channel or homepage rather than a video.",
                    suggestion: "Please navigate to a specific video or Short before copying the URL.",
                    iconName: "film"
                )
            }
        }

        return nil
    }

    public static func parseYtDlpStderr(_ stderr: String) -> AppAnalysisError {
        let lower = stderr.lowercased()

        if lower.contains("private video") {
            return AppAnalysisError(
                title: "Private Video",
                message: "This video has been set to private by the creator.",
                suggestion: "Only viewers with explicit permission can access this video.",
                iconName: "lock.fill"
            )
        }

        if lower.contains("video unavailable") || lower.contains("this video is not available") || lower.contains("has been removed") {
            return AppAnalysisError(
                title: "Video Unavailable",
                message: "This video has been deleted, made unavailable, or copyright-claimed on YouTube.",
                suggestion: "Check if the video is still publicly viewable in a web browser.",
                iconName: "slash.circle.fill"
            )
        }

        if lower.contains("sign in to confirm your age") || lower.contains("age-restricted") {
            return AppAnalysisError(
                title: "Age-Restricted Video",
                message: "YouTube requires account sign-in to confirm your age for this content.",
                suggestion: "Age-restricted content cannot be downloaded without authenticated session cookies.",
                iconName: "person.badge.shield.checkmark.fill"
            )
        }

        if lower.contains("not available in your country") || lower.contains("blocked in your country") || lower.contains("geographic") {
            return AppAnalysisError(
                title: "Region Restricted",
                message: "The uploader has restricted viewing in your country or region.",
                suggestion: "This video is not available in your geographic location due to copyright terms.",
                iconName: "globe.badge.chevron.backward"
            )
        }

        if lower.contains("live event will begin in") || lower.contains("premieres in") || lower.contains("live stream recording is not available") {
            return AppAnalysisError(
                title: "Live Stream or Upcoming Premiere",
                message: "This broadcast has not started or is currently streaming live.",
                suggestion: "Live streams can only be downloaded after the broadcast finishes and processes.",
                iconName: "clock.badge.exclamationmark"
            )
        }

        if lower.contains("nodename nor servname") || lower.contains("network is unreachable") || lower.contains("connection refused") || lower.contains("timed out") || lower.contains("failed to connect") {
            return AppAnalysisError(
                title: "Connection Failed",
                message: "Could not connect to YouTube servers.",
                suggestion: "Please check your Mac's internet connection and try again.",
                iconName: "wifi.slash"
            )
        }

        if lower.contains("incomplete youtube id") || lower.contains("does not look like a youtube url") || lower.contains("is not a valid url") {
            return AppAnalysisError(
                title: "Invalid YouTube Link",
                message: "YouTube could not recognize this video link format.",
                suggestion: "Please re-copy the URL directly using YouTube's Share button.",
                iconName: "link.badge.plus"
            )
        }

        // Clean fallback
        let lines = stderr.components(separatedBy: .newlines)
        var cleanMessage = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Unable to analyze link"
        cleanMessage = cleanMessage.replacingOccurrences(of: "ERROR: [youtube] ", with: "")
        cleanMessage = cleanMessage.replacingOccurrences(of: "ERROR: [generic] ", with: "")
        cleanMessage = cleanMessage.replacingOccurrences(of: "ERROR: ", with: "")

        return AppAnalysisError(
            title: "Analysis Error",
            message: cleanMessage,
            suggestion: "Please verify that the URL is correct and public on YouTube.",
            iconName: "exclamationmark.triangle.fill"
        )
    }
}
