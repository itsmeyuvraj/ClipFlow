import SwiftUI
import AppKit

@main
struct ClipFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(downloadManager)
                .frame(minWidth: 780, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Paste and Analyze URL") {
                    if let pb = NSPasteboard.general.string(forType: .string) {
                        downloadManager.inputUrl = pb
                        downloadManager.analyzeUrl(pb)
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Open Downloads Folder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadManager.downloadDirectory)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandMenu("Downloads") {
                Button("Clear Completed Downloads") {
                    downloadManager.clearCompleted()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Refresh Engine Status") {
                    Task {
                        await downloadManager.refreshBinaryStatus()
                    }
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
