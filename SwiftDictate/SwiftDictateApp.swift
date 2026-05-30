import SwiftUI

@main
struct SwiftDictateApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var onboardingShown = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .task {
                    await appState.initialize()
                    if !appState.hasRequiredPermissions, !onboardingShown {
                        onboardingShown = true
                        showOnboarding()
                    }
                    appState.hotkeyService.start()
                }
        } label: {
            if appState.isRecording {
                Image(systemName: "mic.fill")
            } else {
                Image(systemName: "mic")
            }
        }
        .menuBarExtraStyle(.window)
    }

    func showOnboarding() {
        let onboardingVC = NSHostingController(
            rootView: PermissionsOnboardingView()
                .environment(appState)
                .onChange(of: appState.hasRequiredPermissions) { _, hasPermissions in
                    if hasPermissions {
                        if let window = NSApplication.shared.windows.first(where: {
                            $0.title.contains("Welcome")
                        }) {
                            window.close()
                        }
                    }
                }
        )

        let window = NSWindow(contentViewController: onboardingVC)
        window.title = "Welcome to SwiftDictate"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 440, height: 520))
        window.center()
        window.isReleasedWhenClosed = true
        window.makeKeyAndOrderFront(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
