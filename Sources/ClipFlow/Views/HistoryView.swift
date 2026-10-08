import SwiftUI
import AppKit

public struct HistoryView: View {
    @ObservedObject var manager = DownloadManager.shared

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download History")
                            .font(.system(size: 18, weight: .bold))
                        Text("\(manager.completedTasks.count) item(s)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !manager.completedTasks.isEmpty {
                        Button(action: {
                            manager.clearCompleted()
                        }) {
                            Label("Clear History", systemImage: "trash")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if manager.completedTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("No history yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Completed downloads will appear here.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(manager.completedTasks) { task in
                            HistoryRow(task: task)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct HistoryRow: View {
    let task: DownloadTaskItem
    @ObservedObject var manager = DownloadManager.shared

    var body: some View {
        GlassCard(cornerRadius: 10, padding: 10) {
            HStack(spacing: 12) {
                // Status icon
                statusIcon

                // Details
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.videoInfo.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        StatusBadge(text: task.summaryLabel, icon: task.category.iconName, color: badgeColor)

                        if let date = task.completedAt {
                            Text(dateFormatted(date))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        if case .failed(let msg) = task.status {
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: 6) {
                    if let path = task.downloadedFilePath, FileManager.default.fileExists(atPath: path) {
                        Button(action: {
                            manager.openFile(filePath: path)
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Play File")

                        Button(action: {
                            manager.revealInFinder(filePath: path)
                        }) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")
                    }

                    Button(action: {
                        manager.deleteHistoryItem(id: task.id)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from history")
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(count: 2) {
            if let path = task.downloadedFilePath {
                manager.openFile(filePath: path)
            }
        }
        .contextMenu {
            if let path = task.downloadedFilePath, FileManager.default.fileExists(atPath: path) {
                Button(action: {
                    manager.openFile(filePath: path)
                }) {
                    Label(task.category == .audio ? "Open Audio Directly" : "Open Video Directly", systemImage: "play.fill")
                }

                Button(action: {
                    manager.revealInFinder(filePath: path)
                }) {
                    Label("Open Containing Folder", systemImage: "folder")
                }

                Divider()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }) {
                    Label("Copy File Path", systemImage: "doc.on.doc")
                }
            } else {
                Button(action: {
                    manager.revealInFinder(filePath: task.downloadedFilePath)
                }) {
                    Label("Open Containing Folder", systemImage: "folder")
                }
            }

            if let url = URL(string: task.videoInfo.webpageUrl) {
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    Label("Open on YouTube", systemImage: "arrow.up.right.square")
                }
            }

            Divider()

            Button(role: .destructive, action: {
                manager.deleteHistoryItem(id: task.id)
            }) {
                Label("Remove from History", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 18))
        case .cancelled:
            Image(systemName: "slash.circle")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
        default:
            Image(systemName: "questionmark.circle")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
        }
    }

    private var badgeColor: Color {
        switch task.status {
        case .completed: return .accentColor
        case .failed: return .red
        default: return .secondary
        }
    }

    private func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
