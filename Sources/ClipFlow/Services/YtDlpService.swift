import Foundation

private final class ProtectedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    func mutate(_ block: (inout T) -> Void) {
        lock.lock()
        block(&value)
        lock.unlock()
    }

    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: T) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}

public final class YtDlpService: @unchecked Sendable {
    public static let shared = YtDlpService()

    private init() {}

    public enum ServiceError: LocalizedError {
        case binaryNotFound(String)
        case executionFailed(String)
        case parsingFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .binaryNotFound(let msg): return "Executable not found: \(msg)"
            case .executionFailed(let msg): return msg
            case .parsingFailed(let msg): return "Failed to parse video metadata: \(msg)"
            case .cancelled: return "Download was cancelled."
            }
        }
    }

    public struct ProgressUpdate: Sendable {
        public let progressFraction: Double
        public let percentString: String
        public let speed: String
        public let eta: String
        public let downloadedBytes: Int64
        public let totalBytes: Int64
        public let filename: String?
        public let stage: String?
    }

    /// Fetches all video details and formats as JSON
    public func fetchMetadata(
        url: String,
        ytDlpPath: String? = nil
    ) async throws -> VideoInfo {
        guard let binary = BinaryManager.shared.findExecutable(named: "yt-dlp", customPath: ytDlpPath) else {
            throw ServiceError.binaryNotFound("yt-dlp could not be found.")
        }

        let cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty else {
            throw ServiceError.executionFailed("Please enter a valid URL.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = [
                    "--dump-single-json",
                    "--no-playlist",
                    "--skip-download",
                    "--no-warnings",
                    cleanUrl
                ]

                var env = ProcessInfo.processInfo.environment
                let extraPath = "/opt/homebrew/bin:/usr/local/bin:~/.local/bin:/usr/bin:/bin"
                env["PATH"] = "\(extraPath):\(env["PATH"] ?? "")"
                process.environment = env

                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let dataBox = ProtectedBox<Data>(Data())

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if !chunk.isEmpty {
                        dataBox.mutate { $0.append(chunk) }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    stdoutPipe.fileHandleForReading.readabilityHandler = nil

                    let remainder = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    dataBox.mutate { $0.append(remainder) }
                    let finalData = dataBox.get()

                    if process.terminationStatus == 0 {
                        do {
                            let videoInfo = try VideoInfo.parseFromYtDlpJSON(finalData)
                            continuation.resume(returning: videoInfo)
                        } catch {
                            continuation.resume(throwing: ServiceError.parsingFailed(error.localizedDescription))
                        }
                    } else {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errString = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanErr = errString?.components(separatedBy: "\n").last ?? "yt-dlp terminated with code \(process.terminationStatus)"
                        continuation.resume(throwing: ServiceError.executionFailed(cleanErr))
                    }
                } catch {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: ServiceError.executionFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Spawns a download process and streams progress callbacks
    public func startDownload(
        task: DownloadTaskItem,
        ytDlpPath: String? = nil,
        ffmpegPath: String? = nil,
        onProgress: @escaping @Sendable (ProgressUpdate) -> Void,
        onComplete: @escaping @Sendable (Result<String, Error>) -> Void
    ) -> Process? {
        guard let binary = BinaryManager.shared.findExecutable(named: "yt-dlp", customPath: ytDlpPath) else {
            onComplete(.failure(ServiceError.binaryNotFound("yt-dlp")))
            return nil
        }

        let ffmpeg = BinaryManager.shared.findExecutable(named: "ffmpeg", customPath: ffmpegPath)

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: binary)

        var args: [String] = [
            "--newline",
            "--progress-template",
            "clipflow:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._total_bytes_estimate_str)s|%(progress._downloaded_bytes_str)s|%(progress.filename)s",
            "--no-playlist",
            "-P", task.destinationFolder,
            "-o", "%(title)s [%(id)s].%(ext)s"
        ]

        if let ffmpeg = ffmpeg {
            let ffmpegDir = (ffmpeg as NSString).deletingLastPathComponent
            args.append(contentsOf: ["--ffmpeg-location", ffmpegDir])
        }

        // Format selection
        switch task.category {
        case .video:
            let preset = task.videoPreset ?? .best
            let formatSelector = preset.ytDlpFormatSelector(container: task.videoContainer)
            args.append(contentsOf: ["-f", formatSelector])
            args.append(contentsOf: ["--merge-output-format", task.videoContainer.rawValue])

        case .audio:
            args.append(contentsOf: [
                "-x",
                "--audio-format", task.audioContainer.rawValue,
                "--audio-quality", "0"
            ])

        case .customStream:
            if let fId = task.selectedFormatId {
                if let matched = task.videoInfo.formats.first(where: { $0.formatId == fId }) {
                    if matched.isVideoOnly {
                        args.append(contentsOf: ["-f", "\(fId)+bestaudio/best"])
                        args.append(contentsOf: ["--merge-output-format", "mp4"])
                    } else {
                        args.append(contentsOf: ["-f", fId])
                    }
                } else {
                    args.append(contentsOf: ["-f", fId])
                }
            } else {
                args.append(contentsOf: ["-f", "bestvideo+bestaudio/best"])
            }
        }

        if task.embedThumbnail {
            args.append("--embed-thumbnail")
        }
        if task.embedChapters {
            args.append("--embed-chapters")
        }
        if task.embedSubtitles {
            args.append(contentsOf: ["--write-subs", "--sub-langs", "en.*,all", "--embed-subs"])
        }
        args.append("--embed-metadata")

        args.append(task.videoInfo.webpageUrl)

        var env = ProcessInfo.processInfo.environment
        let extraPath = "/opt/homebrew/bin:/usr/local/bin:~/.local/bin:/usr/bin:/bin"
        env["PATH"] = "\(extraPath):\(env["PATH"] ?? "")"
        process.environment = env

        process.arguments = args
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let downloadedPathBox = ProtectedBox<String?>(nil)

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            let lines = text.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("clipflow:") {
                    let payload = String(trimmed.dropFirst("clipflow:".count))
                    let parts = payload.components(separatedBy: "|")
                    let pctStr = parts.indices.contains(0) ? parts[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces) : "0"
                    let speedStr = parts.indices.contains(1) ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                    let etaStr = parts.indices.contains(2) ? parts[2].trimmingCharacters(in: .whitespaces) : ""
                    let totalStr = parts.indices.contains(3) ? parts[3].trimmingCharacters(in: .whitespaces) : ""
                    let dlStr = parts.indices.contains(4) ? parts[4].trimmingCharacters(in: .whitespaces) : ""
                    let file = parts.indices.contains(5) ? parts[5].trimmingCharacters(in: .whitespaces) : nil

                    if let f = file, !f.isEmpty {
                        downloadedPathBox.set(f)
                    }

                    let pctValue = (Double(pctStr) ?? 0.0) / 100.0
                    let dlBytes = Int64(dlStr) ?? 0
                    let totalBytes = Int64(totalStr) ?? 0

                    onProgress(ProgressUpdate(
                        progressFraction: min(max(pctValue, 0.0), 1.0),
                        percentString: pctStr,
                        speed: speedStr,
                        eta: etaStr,
                        downloadedBytes: dlBytes,
                        totalBytes: totalBytes,
                        filename: file,
                        stage: nil
                    ))
                } else if trimmed.contains("[Merger]") || trimmed.contains("Merging formats") {
                    onProgress(ProgressUpdate(
                        progressFraction: 0.98,
                        percentString: "98",
                        speed: "",
                        eta: "",
                        downloadedBytes: 0,
                        totalBytes: 0,
                        filename: nil,
                        stage: "Merging video & audio streams..."
                    ))
                } else if trimmed.contains("[ExtractAudio]") {
                    onProgress(ProgressUpdate(
                        progressFraction: 0.98,
                        percentString: "98",
                        speed: "",
                        eta: "",
                        downloadedBytes: 0,
                        totalBytes: 0,
                        filename: nil,
                        stage: "Extracting audio track..."
                    ))
                } else if trimmed.hasPrefix("[download] Destination:") {
                    let dest = trimmed.replacingOccurrences(of: "[download] Destination:", with: "").trimmingCharacters(in: .whitespaces)
                    downloadedPathBox.set(dest)
                }
            }
        }

        do {
            try process.run()
        } catch {
            onComplete(.failure(error))
            return nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            stdoutPipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus == 0 {
                let resultPath = downloadedPathBox.get()
                let finalFile = resultPath ?? self.findDownloadedFile(in: task.destinationFolder, videoId: task.videoInfo.id)
                onComplete(.success(finalFile ?? task.destinationFolder))
            } else {
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errString = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanErr = errString?.components(separatedBy: .newlines).last ?? "Process failed with status \(process.terminationStatus)"
                onComplete(.failure(ServiceError.executionFailed(cleanErr)))
            }
        }

        return process
    }

    private func findDownloadedFile(in folder: String, videoId: String) -> String? {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: folder) else { return nil }
        let matches = files.filter { $0.contains(videoId) }
        guard let latest = matches.sorted(by: { f1, f2 in
            let path1 = (folder as NSString).appendingPathComponent(f1)
            let path2 = (folder as NSString).appendingPathComponent(f2)
            let date1 = (try? fileManager.attributesOfItem(atPath: path1)[.modificationDate] as? Date) ?? Date.distantPast
            let date2 = (try? fileManager.attributesOfItem(atPath: path2)[.modificationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }).first else { return nil }

        return (folder as NSString).appendingPathComponent(latest)
    }
}
