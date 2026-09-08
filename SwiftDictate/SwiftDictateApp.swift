import SwiftUI

@main
struct SwiftDictateApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            let activity = appState.recordingState.menuBarActivity
            Image(systemName: activity.microphoneSymbolName)
                .foregroundStyle(
                    activity == .recording ? .red : activity == .processing ? .yellow : .primary
                )
                .symbolRenderingMode(.monochrome)
                .accessibilityLabel(appState.recordingState.displayName)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
