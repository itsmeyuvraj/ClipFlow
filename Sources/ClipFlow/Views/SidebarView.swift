import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable {
    case downloader = "Downloader"
    case queue = "Queue"
    case history = "History"
    case settings = "Settings"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .downloader: return "arrow.down.circle"
        case .queue: return "arrow.down.to.line.compact"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

public struct SidebarView: View {
    @Binding public var selection: NavigationSection?
    @ObservedObject var manager = DownloadManager.shared

    public var body: some View {
        List(selection: $selection) {
            Section("Library") {
                NavigationLink(value: NavigationSection.downloader) {
                    Label(NavigationSection.downloader.rawValue, systemImage: NavigationSection.downloader.iconName)
                }

                NavigationLink(value: NavigationSection.queue) {
                    HStack {
                        Label(NavigationSection.queue.rawValue, systemImage: NavigationSection.queue.iconName)
                        Spacer()
                        if !manager.activeTasks.isEmpty {
                            Text("\(manager.activeTasks.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }
                    }
                }

                NavigationLink(value: NavigationSection.history) {
                    HStack {
                        Label(NavigationSection.history.rawValue, systemImage: NavigationSection.history.iconName)
                        Spacer()
                        if !manager.completedTasks.isEmpty {
                            Text("\(manager.completedTasks.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("System") {
                NavigationLink(value: NavigationSection.settings) {
                    Label(NavigationSection.settings.rawValue, systemImage: NavigationSection.settings.iconName)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180, idealWidth: 200)
    }
}
