import Testing
import Foundation
@testable import ClipFlow

@Suite("ClipFlow Tests")
struct ClipFlowTests {

    @Test("Test FormatItem Stream Categorization")
    func testFormatItemCategorization() {
        let videoOnly = FormatItem(
            formatId: "137",
            ext: "mp4",
            formatNote: "1080p",
            resolution: "1920x1080",
            width: 1920,
            height: 1080,
            fps: 60,
            vcodec: "avc1.640028",
            acodec: "none",
            filesize: 150_000_000
        )
        #expect(videoOnly.isVideoOnly)
        #expect(!videoOnly.isAudioOnly)
        #expect(!videoOnly.isMuxedVideoAndAudio)
        #expect(videoOnly.qualityLabel == "1080p Full HD")

        let audioOnly = FormatItem(
            formatId: "140",
            ext: "m4a",
            formatNote: "medium",
            vcodec: "none",
            acodec: "mp4a.40.2",
            abr: 128
        )
        #expect(audioOnly.isAudioOnly)
        #expect(!audioOnly.isVideoOnly)
        #expect(audioOnly.qualityLabel == "128 kbps Audio")

        let muxed = FormatItem(
            formatId: "18",
            ext: "mp4",
            formatNote: "360p",
            resolution: "640x360",
            height: 360,
            vcodec: "avc1.42001E",
            acodec: "mp4a.40.2"
        )
        #expect(muxed.isMuxedVideoAndAudio)
        #expect(!muxed.isVideoOnly)
        #expect(!muxed.isAudioOnly)

        let storyboard = FormatItem(
            formatId: "sb0",
            ext: "mhtml",
            formatNote: "storyboard"
        )
        #expect(storyboard.isStoryboard)
    }

    @Test("Test VideoInfo JSON Parsing")
    func testVideoInfoParsing() throws {
        let sampleJSON = """
        {
            "id": "dQw4w9WgXcQ",
            "title": "Rick Astley - Never Gonna Give You Up",
            "duration": 213,
            "uploader": "Rick Astley",
            "view_count": 1400000000,
            "upload_date": "20091025",
            "webpage_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "formats": [
                {
                    "format_id": "137",
                    "ext": "mp4",
                    "format_note": "1080p",
                    "width": 1920,
                    "height": 1080,
                    "fps": 30,
                    "vcodec": "avc1.640028",
                    "acodec": "none",
                    "filesize": 120000000
                },
                {
                    "format_id": "140",
                    "ext": "m4a",
                    "vcodec": "none",
                    "acodec": "mp4a.40.2",
                    "abr": 128,
                    "filesize": 3500000
                },
                {
                    "format_id": "sb0",
                    "ext": "mhtml",
                    "format_note": "storyboard"
                }
            ]
        }
        """

        let data = sampleJSON.data(using: .utf8)!
        let video = try VideoInfo.parseFromYtDlpJSON(data)

        #expect(video.id == "dQw4w9WgXcQ")
        #expect(video.title == "Rick Astley - Never Gonna Give You Up")
        #expect(video.formattedDuration == "3:33")
        #expect(video.authorName == "Rick Astley")
        #expect(video.formattedViewCount == "1.4B views")
        #expect(video.formattedUploadDate == "2009-10-25")

        // Check format filtering
        #expect(video.formats.count == 3)
        #expect(video.validFormats.count == 2)
        #expect(video.videoFormats.count == 1)
        #expect(video.audioFormats.count == 1)
        #expect(video.availableResolutions == [1080])
    }

    @Test("Test QualityPreset Selectors")
    func testQualityPresets() {
        let bestSelector = QualityPreset.best.ytDlpFormatSelector(container: .mp4)
        #expect(bestSelector == "bestvideo+bestaudio/best")

        let fhdSelector = QualityPreset.fhd1080.ytDlpFormatSelector(container: .mp4)
        #expect(fhdSelector.contains("height<=1080"))

        let uhdSelector = QualityPreset.uhd4k.ytDlpFormatSelector(container: .mp4)
        #expect(uhdSelector.contains("height<=2160"))
    }

    @Test("Test Binary Detection")
    func testBinaryDetection() {
        let ytDlp = BinaryManager.shared.findExecutable(named: "yt-dlp")
        #expect(ytDlp != nil)

        let ffmpeg = BinaryManager.shared.findExecutable(named: "ffmpeg")
        #expect(ffmpeg != nil)
    }

    @Test("Test Invalid URL Handling")
    func testInvalidUrlHandling() {
        // Empty
        let emptyErr = AnalysisErrorParser.validateUrl("   ")
        #expect(emptyErr != nil)
        #expect(emptyErr?.title == "Empty URL")

        // Plain text (not a URL)
        let textErr = AnalysisErrorParser.validateUrl("some random video search")
        #expect(textErr != nil)
        #expect(textErr?.title == "Invalid Web Link")

        // Non-YouTube link
        let nonYtErr = AnalysisErrorParser.validateUrl("https://example.com/video.mp4")
        #expect(nonYtErr != nil)
        #expect(nonYtErr?.title == "Non-YouTube Link")

        // Incomplete youtu.be link
        let incompleteYtErr = AnalysisErrorParser.validateUrl("https://youtu.be/")
        #expect(incompleteYtErr != nil)
        #expect(incompleteYtErr?.title == "Incomplete YouTube Link")

        // Missing ?v= parameter in watch link
        let missingParamErr = AnalysisErrorParser.validateUrl("https://www.youtube.com/watch")
        #expect(missingParamErr != nil)
        #expect(missingParamErr?.title == "Missing Video ID")

        // Channel or Homepage link
        let channelErr = AnalysisErrorParser.validateUrl("https://www.youtube.com/@mkbhd")
        #expect(channelErr != nil)
        #expect(channelErr?.title == "Not a Video Link")

        // Valid URLs should return nil
        #expect(AnalysisErrorParser.validateUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(AnalysisErrorParser.validateUrl("https://youtu.be/dQw4w9WgXcQ") == nil)
        #expect(AnalysisErrorParser.validateUrl("https://www.youtube.com/shorts/5xYg1z2A_bC") == nil)
    }

    @Test("Test yt-dlp Stderr Error Parser")
    func testYtDlpStderrParser() {
        let privateErr = AnalysisErrorParser.parseYtDlpStderr("ERROR: [youtube] dQw4w9WgXcQ: Private video. Sign in if you've been granted access.")
        #expect(privateErr.title == "Private Video")

        let unavailableErr = AnalysisErrorParser.parseYtDlpStderr("ERROR: [youtube] dQw4w9WgXcQ: Video unavailable")
        #expect(unavailableErr.title == "Video Unavailable")

        let networkErr = AnalysisErrorParser.parseYtDlpStderr("ERROR: [Errno 8] nodename nor servname provided, or not known")
        #expect(networkErr.title == "Connection Failed")

        let ageErr = AnalysisErrorParser.parseYtDlpStderr("ERROR: [youtube] Sign in to confirm your age")
        #expect(ageErr.title == "Age-Restricted Video")
    }
}
