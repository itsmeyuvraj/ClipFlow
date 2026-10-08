import Foundation

public final class BinaryManager: @unchecked Sendable {
    public static let shared = BinaryManager()

    public struct BinaryStatus: Equatable, Sendable {
        public let isAvailable: Bool
        public let path: String?
        public let version: String?
        public let errorMessage: String?
    }

    private let standardSearchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "\(NSHomeDirectory())/.local/bin",
        "/usr/bin",
        "/bin"
    ]

    private init() {}

    public func findExecutable(named name: String, customPath: String? = nil) -> String? {
        if let custom = customPath, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            let path = (custom as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        for dir in standardSearchPaths {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        // Try shell which lookup
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(name)"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    if FileManager.default.isExecutableFile(atPath: str) {
                        return str
                    }
                }
            }
        } catch {}

        return nil
    }

    public func checkYtDlp(customPath: String? = nil) async -> BinaryStatus {
        guard let path = findExecutable(named: "yt-dlp", customPath: customPath) else {
            return BinaryStatus(
                isAvailable: false,
                path: nil,
                version: nil,
                errorMessage: "yt-dlp was not found. Please install it via Homebrew (`brew install yt-dlp`) or specify its path in Settings."
            )
        }

        let version = await runVersionCheck(executable: path, arg: "--version")
        return BinaryStatus(isAvailable: true, path: path, version: version, errorMessage: nil)
    }

    public func checkFfmpeg(customPath: String? = nil) async -> BinaryStatus {
        guard let path = findExecutable(named: "ffmpeg", customPath: customPath) else {
            return BinaryStatus(
                isAvailable: false,
                path: nil,
                version: nil,
                errorMessage: "ffmpeg was not found. Recommended for merging HD video and audio streams (`brew install ffmpeg`)."
            )
        }

        let version = await runVersionCheck(executable: path, arg: "-version")
        let firstLine = version?.components(separatedBy: .newlines).first
        return BinaryStatus(isAvailable: true, path: path, version: firstLine ?? version, errorMessage: nil)
    }

    private func runVersionCheck(executable: String, arg: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = [arg]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: str)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
