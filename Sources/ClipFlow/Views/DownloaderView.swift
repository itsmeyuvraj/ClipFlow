import SwiftUI
import AppKit

public struct DownloaderView: View {
    @ObservedObject var manager = DownloadManager.shared

    @State private var category: DownloadTargetCategory = .video
    @State private var selectedPreset: QualityPreset = .best
    @State private var selectedVideoContainer: VideoContainerFormat = .mp4
    @State private var selectedAudioContainer: AudioContainerFormat = .mp3
    @State private var selectedCustomFormatId: String? = nil

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Search & Input Bar
                inputSection

                // Error Message if any
                if let error = manager.analyzeError {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: error.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(error.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)

                            Text(error.message)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let suggestion = error.suggestion {
                                Text(suggestion)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .padding(.top, 2)
                            }
                        }

                        Spacer()

                        Button(action: {
                            manager.analyzeError = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Dismiss error")
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Loading State
                if manager.isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.1)
                        Text("Extracting video formats and streams...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if let video = manager.analyzedVideo {
                    // Analyzed Video Info & Controls
                    VStack(alignment: .leading, spacing: 16) {
                        // Hero Card
                        VideoHeroCard(video: video)

                        // Format Selection Card
                        GlassCard(cornerRadius: 14, padding: 16) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Download Format & Quality", systemImage: "slider.horizontal.3")
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                }

                                FormatPickerView(
                                    video: video,
                                    category: $category,
                                    selectedPreset: $selectedPreset,
                                    selectedVideoContainer: $selectedVideoContainer,
                                    selectedAudioContainer: $selectedAudioContainer,
                                    selectedCustomFormatId: $selectedCustomFormatId,
                                    onTriggerDownload: {
                                        triggerDownload(video: video)
                                    }
                                )
                            }
                        }

                        // Download Options & Destination Card
                        GlassCard(cornerRadius: 14, padding: 14) {
                            VStack(spacing: 12) {
                                HStack(spacing: 16) {
                                    Toggle("Embed Thumbnail", isOn: $manager.embedThumbnail)
                                        .toggleStyle(.checkbox)
                                    Toggle("Embed Chapters", isOn: $manager.embedChapters)
                                        .toggleStyle(.checkbox)
                                    Toggle("Subtitles", isOn: $manager.embedSubtitles)
                                        .toggleStyle(.checkbox)

                                    Spacer()
                                }
                                .font(.system(size: 12))

                                Divider()

                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 12))
                                        Text("Save to:")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text(manager.downloadDirectory)
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Button("Change...") {
                                        chooseDirectory()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                        // Download Action Button
                        HStack {
                            Spacer()
                            Button(action: {
                                triggerDownload(video: video)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Download Video")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 10)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.9), Color.red],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: Color.red.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                } else {
                    // Empty State
                    emptyStateView
                }
            }
            .padding(20)
        }
        .onAppear {
            manager.checkClipboardForUrl()
        }
    }

    // MARK: - Input Section
    private var inputSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))

                TextField("Paste YouTube link (e.g. https://www.youtube.com/watch?v=...)", text: $manager.inputUrl)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        manager.analyzeUrl(manager.inputUrl)
                    }

                if !manager.inputUrl.isEmpty {
                    Button(action: { manager.inputUrl = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )

            // Paste Button
            Button(action: {
                if let pb = NSPasteboard.general.string(forType: .string) {
                    manager.inputUrl = pb
                    manager.analyzeUrl(pb)
                }
            }) {
                Label("Paste", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            // Analyze Button
            Button(action: {
                manager.analyzeUrl(manager.inputUrl)
            }) {
                if manager.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 50)
                } else {
                    Text("Analyze")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(manager.inputUrl.trimmingCharacters(in: .whitespaces).isEmpty || manager.isAnalyzing)
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.12), Color.orange.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 42))
                    .foregroundColor(.red)
            }
            .padding(.top, 40)

            VStack(spacing: 6) {
                Text("Ready to Download")
                    .font(.system(size: 18, weight: .bold))
                Text("Paste any YouTube video or Shorts URL to inspect all supported video, audio, and raw streams.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Button(action: {
                if let pb = NSPasteboard.general.string(forType: .string) {
                    manager.inputUrl = pb
                    manager.analyzeUrl(pb)
                }
            }) {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Folder"
        if panel.runModal() == .OK, let url = panel.url {
            manager.downloadDirectory = url.path
        }
    }

    private func triggerDownload(video: VideoInfo) {
        manager.queueDownload(
            videoInfo: video,
            category: category,
            preset: category == .video ? selectedPreset : nil,
            videoContainer: selectedVideoContainer,
            audioContainer: selectedAudioContainer,
            formatId: category == .customStream ? selectedCustomFormatId : nil
        )
    }
}
