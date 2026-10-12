import SwiftUI
import AppKit

@main
@MainActor
struct MactivityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var stats = StatsStore()
    @StateObject private var processes = ProcessStore()
    @StateObject private var connection = ConnectionStore()

    var body: some Scene {
        WindowGroup("Mactivity") {
            ContentView()
                .environmentObject(stats)
                .environmentObject(processes)
                .environmentObject(connection)
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1220, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Refresh Now") {
                    processes.refreshNow()
                    Task { await connection.runChecks() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Brings the window forward even when launched from Terminal or Xcode.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
