import SwiftUI

@main
struct FQEncoderApp: App {
    @ObservedObject private var monitor = ClipboardMonitor.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Main editor window (phase 1).
        Window("FQEncoder", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)

        // Menu-bar resident icon (phase 2).
        MenuBarExtra("FQEncoder", systemImage: "wand.and.stars") {
            Toggle("自動監聽剪貼簿", isOn: $monitor.isEnabled)

            Divider()

            Text(monitor.lastAction)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("打開主視窗") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("o")

            SettingsLink {
                Text("設定…")
            }
            .keyboardShortcut(",")

            Button("結束 FQEncoder") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        // Preferences window (⌘,) for the encoding password.
        Settings {
            SettingsView()
        }
    }
}
