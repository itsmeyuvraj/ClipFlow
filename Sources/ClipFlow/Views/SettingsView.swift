import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var manager = DownloadManager.shared

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold))

                // Engine / Binaries Section
                GlassCard(cornerRadius: 12, padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Core Tools & Dependencies", systemImage: "wrench.and.screwdriver.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Button("Check Again") {
                                Task {
                                    await manager.refreshBinaryStatus()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Divider()

                        // yt-dlp status
                        binaryStatusRow(
                            name: "yt-dlp",
                            status: manager.ytDlpStatus,
                            customPath: $manager.customYtDlpPath,
                            helpText: "Homebrew path: /opt/homebrew/bin/yt-dlp"
                        )

                        Divider()

                        // ffmpeg status
                        binaryStatusRow(
                            name: "ffmpeg",
                            status: manager.ffmpegStatus,
                            customPath: $manager.customFfmpegPath,
                            helpText: "Required for merging high-res streams & converting audio formats"
                        )
                    }
                }

                // Storage & Directories
                GlassCard(cornerRadius: 12, padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Storage & Output", systemImage: "folder.fill")
                            .font(.system(size: 14, weight: .semibold))

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Default Download Location")
                                    .font(.system(size: 13, weight: .medium))
                                Text(manager.downloadDirectory)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Browse...") {
                                chooseDirectory()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                // Metadata & Notification Preferences
                GlassCard(cornerRadius: 12, padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Preferences & Metadata", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))

                        Divider()

                        Toggle("Embed video thumbnail as cover artwork", isOn: $manager.embedThumbnail)
                            .toggleStyle(.checkbox)
                        Toggle("Embed chapter markers in video files", isOn: $manager.embedChapters)
                            .toggleStyle(.checkbox)
                        Toggle("Download & embed subtitles by default", isOn: $manager.embedSubtitles)
                            .toggleStyle(.checkbox)
                        Toggle("Show macOS notification when download finishes", isOn: $manager.notifyOnCompletion)
                            .toggleStyle(.checkbox)
                    }
                    .font(.system(size: 13))
                }

                // App Info
                GlassCard(cornerRadius: 12, padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("ClipFlow for macOS")
                                .font(.system(size: 13, weight: .bold))
                            Text("Fast, native YouTube video & audio downloader.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("v1.0")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }

    private func binaryStatusRow(
        name: String,
        status: BinaryManager.BinaryStatus,
        customPath: Binding<String>,
        helpText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.isAvailable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                }

                Spacer()

                if status.isAvailable {
                    Text(status.version ?? "Available")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("Missing")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                }
            }

            if let path = status.path {
                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            } else if let err = status.errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }

            // Custom Path Input
            HStack(spacing: 6) {
                Text("Custom Path:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Optional custom path", text: customPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
            }
            .padding(.top, 2)
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            manager.downloadDirectory = url.path
        }
    }
}
