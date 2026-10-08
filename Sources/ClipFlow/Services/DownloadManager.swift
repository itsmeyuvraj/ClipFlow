import Foundation
import AppKit
import Combine
import UserNotifications

@MainActor
public final class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()

    // Download state
    @Published public var activeTasks: [DownloadTaskItem] = []
    @Published public var completedTasks: [DownloadTaskItem] = []

    // Video analysis state
    @Published public var inputUrl: String = ""
    @Published public var isAnalyzing: Bool = false
    @Published public var analyzedVideo: VideoInfo? = nil
    @Published public var analyzeError: AppAnalysisError? = nil

    // System binary status
    @Published public var ytDlpStatus: BinaryManager.BinaryStatus = .init(isAvailable: false, path: nil, version: nil, errorMessage: nil)
    @Published public var ffmpegStatus: BinaryManager.BinaryStatus = .init(isAvailable: false, path: nil, version: nil, errorMessage: nil)

    // User preferences
    @Published public var downloadDirectory: String {
        didSet { UserDefaults.standard.set(downloadDirectory, forKey: "ClipFlow_downloadDirectory") }
    }
    @Published public var customYtDlpPath: String {
        didSet {
            UserDefaults.standard.set(customYtDlpPath, forKey: "ClipFlow_customYtDlpPath")
            Task { await refreshBinaryStatus() }
        }
    }
    @Published public var customFfmpegPath: String {
        didSet {
            UserDefaults.standard.set(customFfmpegPath, forKey: "ClipFlow_customFfmpegPath")
            Task { await refreshBinaryStatus() }
        }
    }
    @Published public var embedThumbnail: Bool {
        didSet { UserDefaults.standard.set(embedThumbnail, forKey: "ClipFlow_embedThumbnail") }
    }
    @Published public var embedSubtitles: Bool {
        didSet { UserDefaults.standard.set(embedSubtitles, forKey: "ClipFlow_embedSubtitles") }
    }
    @Published public var embedChapters: Bool {
        didSet { UserDefaults.standard.set(embedChapters, forKey: "ClipFlow_embedChapters") }
    }
    @Published public var notifyOnCompletion: Bool {
        didSet { UserDefaults.standard.set(notifyOnCompletion, forKey: "ClipFlow_notifyOnCompletion") }
    }

    private var activeProcesses: [UUID: Process] = [:]
    private var lastCheckedClipboardString: String = ""

    private init() {
        let defaultDownloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
        self.downloadDirectory = UserDefaults.standard.string(forKey: "ClipFlow_downloadDirectory") ?? defaultDownloads
        self.customYtDlpPath = UserDefaults.standard.string(forKey: "ClipFlow_customYtDlpPath") ?? ""
        self.customFfmpegPath = UserDefaults.standard.string(forKey: "ClipFlow_customFfmpegPath") ?? ""
        self.embedThumbnail = UserDefaults.standard.object(forKey: "ClipFlow_embedThumbnail") as? Bool ?? true
        self.embedSubtitles = UserDefaults.standard.object(forKey: "ClipFlow_embedSubtitles") as? Bool ?? false
        self.embedChapters = UserDefaults.standard.object(forKey: "ClipFlow_embedChapters") as? Bool ?? true
        self.notifyOnCompletion = UserDefaults.standard.object(forKey: "ClipFlow_notifyOnCompletion") as? Bool ?? true

        loadHistory()
        Task {
            await refreshBinaryStatus()
        }
        requestNotificationPermission()
    }

    public func refreshBinaryStatus() async {
        let yt = await BinaryManager.shared.checkYtDlp(customPath: customYtDlpPath.isEmpty ? nil : customYtDlpPath)
        let ff = await BinaryManager.shared.checkFfmpeg(customPath: customFfmpegPath.isEmpty ? nil : customFfmpegPath)
        self.ytDlpStatus = yt
        self.ffmpegStatus = ff
    }

    private var isNotificationSupported: Bool {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            return false
        }
        return Bundle.main.bundleURL.pathExtension == "app"
    }

    private func requestNotificationPermission() {
        guard isNotificationSupported else {
            print("[ClipFlow] Desktop notifications disabled: running outside a registered .app bundle.")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Video Analysis

    public func analyzeUrl(_ urlString: String) {
        if let validationError = AnalysisErrorParser.validateUrl(urlString) {
            self.inputUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            self.analyzeError = validationError
            self.isAnalyzing = false
            self.analyzedVideo = nil
            return
        }

        let clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.inputUrl = clean
        self.isAnalyzing = true
        self.analyzeError = nil
        self.analyzedVideo = nil

        Task {
            do {
                let info = try await YtDlpService.shared.fetchMetadata(
                    url: clean,
                    ytDlpPath: customYtDlpPath.isEmpty ? nil : customYtDlpPath
                )
                self.analyzedVideo = info
                self.isAnalyzing = false
            } catch {
                self.analyzeError = AnalysisErrorParser.parseYtDlpStderr(error.localizedDescription)
                self.isAnalyzing = false
            }
        }
    }

    public func checkClipboardForUrl() {
        guard let pbString = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        if (pbString.contains("youtube.com/watch") || pbString.contains("youtu.be/") || pbString.contains("youtube.com/shorts/")) && pbString != lastCheckedClipboardString {
            lastCheckedClipboardString = pbString
            inputUrl = pbString
            analyzeUrl(pbString)
        }
    }

    // MARK: - Queue & Download

    public func queueDownload(
        videoInfo: VideoInfo,
        category: DownloadTargetCategory,
        preset: QualityPreset? = .best,
        videoContainer: VideoContainerFormat = .mp4,
        audioContainer: AudioContainerFormat = .mp3,
        formatId: String? = nil
    ) {
        let task = DownloadTaskItem(
            videoInfo: videoInfo,
            category: category,
            videoPreset: preset,
            videoContainer: videoContainer,
            audioContainer: audioContainer,
            selectedFormatId: formatId,
            destinationFolder: downloadDirectory,
            embedThumbnail: embedThumbnail,
            embedSubtitles: embedSubtitles,
            embedChapters: embedChapters,
            status: .pending
        )

        activeTasks.insert(task, at: 0)
        executeTask(taskId: task.id)
    }

    private func executeTask(taskId: UUID) {
        guard let index = activeTasks.firstIndex(where: { $0.id == taskId }) else { return }
        var currentTask = activeTasks[index]

        currentTask.status = .downloading(progress: 0.0, speed: "Starting...", eta: "", downloadedBytes: 0, totalBytes: 0)
        activeTasks[index] = currentTask

        let ytPath = customYtDlpPath.isEmpty ? nil : customYtDlpPath
        let ffPath = customFfmpegPath.isEmpty ? nil : customFfmpegPath

        let process = YtDlpService.shared.startDownload(
            task: currentTask,
            ytDlpPath: ytPath,
            ffmpegPath: ffPath,
            onProgress: { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if let idx = self.activeTasks.firstIndex(where: { $0.id == taskId }) {
                        var updated = self.activeTasks[idx]
                        if let stage = progress.stage {
                            updated.status = .processing(stage: stage)
                        } else {
                            updated.progress = progress.progressFraction
                            updated.speed = progress.speed
                            updated.eta = progress.eta
                            updated.downloadedBytes = progress.downloadedBytes
                            updated.totalBytes = progress.totalBytes
                            updated.status = .downloading(
                                progress: progress.progressFraction,
                                speed: progress.speed,
                                eta: progress.eta,
                                downloadedBytes: progress.downloadedBytes,
                                totalBytes: progress.totalBytes
                            )
                        }
                        self.activeTasks[idx] = updated
                    }
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.activeProcesses.removeValue(forKey: taskId)

                    if let idx = self.activeTasks.firstIndex(where: { $0.id == taskId }) {
                        var finishedTask = self.activeTasks.remove(at: idx)
                        finishedTask.completedAt = Date()

                        switch result {
                        case .success(let filePath):
                            finishedTask.progress = 1.0
                            finishedTask.status = .completed(outputUrlString: filePath)
                            finishedTask.downloadedFilePath = filePath
                            self.completedTasks.insert(finishedTask, at: 0)
                            self.sendCompletionNotification(task: finishedTask)
                        case .failure(let error):
                            finishedTask.status = .failed(message: error.localizedDescription)
                            self.completedTasks.insert(finishedTask, at: 0)
                        }
                        self.saveHistory()
                    }
                }
            }
        )

        if let proc = process {
            activeProcesses[taskId] = proc
        }
    }

    public func cancelTask(taskId: UUID) {
        if let proc = activeProcesses[taskId] {
            proc.terminate()
            activeProcesses.removeValue(forKey: taskId)
        }

        if let idx = activeTasks.firstIndex(where: { $0.id == taskId }) {
            var task = activeTasks.remove(at: idx)
            task.status = .cancelled
            task.completedAt = Date()
            completedTasks.insert(task, at: 0)
            saveHistory()
        }
    }

    public func clearCompleted() {
        completedTasks.removeAll()
        saveHistory()
    }

    public func deleteHistoryItem(id: UUID) {
        completedTasks.removeAll { $0.id == id }
        saveHistory()
    }

    // MARK: - Actions

    public func revealInFinder(filePath: String?) {
        guard let path = filePath, FileManager.default.fileExists(atPath: path) else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadDirectory)
            return
        }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    public func openFile(filePath: String?) {
        guard let path = filePath, FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: - Notifications

    private func sendCompletionNotification(task: DownloadTaskItem) {
        guard notifyOnCompletion, isNotificationSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.subtitle = task.videoInfo.title
        content.body = "Saved in \(downloadDirectory)"
        content.sound = .default

        let req = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Persistence

    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClipFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(completedTasks)
            try data.write(to: historyFileURL)
        } catch {}
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let items = try? JSONDecoder().decode([DownloadTaskItem].self, from: data) else {
            return
        }
        self.completedTasks = items
    }
}
