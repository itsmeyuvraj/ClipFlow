import SwiftUI
import AppKit

public struct MainContentView: View {
    @State private var selectedSection: NavigationSection? = .downloader
    @ObservedObject var manager = DownloadManager.shared

    public var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection)
        } detail: {
            Group {
                switch selectedSection ?? .downloader {
                case .downloader:
                    DownloaderView()
                case .queue:
                    DownloadsQueueView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 550, minHeight: 450)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    toggleSidebar()
                }) {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Sidebar")
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
