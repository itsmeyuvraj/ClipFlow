import SwiftUI

public struct DownloadsQueueView: View {
    @ObservedObject var manager = DownloadManager.shared

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Downloads")
                            .font(.system(size: 18, weight: .bold))
                        Text("\(manager.activeTasks.count) running task(s)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                if manager.activeTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("No active downloads")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Start a download from the Downloader tab.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.activeTasks) { task in
                            ActiveDownloadRow(task: task) {
                                manager.cancelTask(taskId: task.id)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct ActiveDownloadRow: View {
    let task: DownloadTaskItem
    let onCancel: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 12, padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    // Thumbnail
                    if let thumb = task.videoInfo.thumbnail, let url = URL(string: thumb) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(16/9, contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.primary.opacity(0.06))
                            }
                        }
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    // Title & Badges
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.videoInfo.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        HStack(spacing: 6) {
                            StatusBadge(text: task.summaryLabel, icon: task.category.iconName, color: .accentColor)
                            Text(task.status.statusDescription)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Cancel Button
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel Download")
                }

                // Progress Bar
                ProgressBarView(progress: task.progress, height: 6, accentColor: .red)

                // Stats footer
                HStack {
                    if !task.speed.isEmpty {
                        Label(task.speed, systemImage: "bolt.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if !task.eta.isEmpty {
                        Label("ETA \(task.eta)", systemImage: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if task.totalBytes > 0 {
                        Text("\(formatBytes(task.downloadedBytes)) / \(formatBytes(task.totalBytes))")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
