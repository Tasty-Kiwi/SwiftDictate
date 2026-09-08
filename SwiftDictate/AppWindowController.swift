import AppKit
import SwiftUI

@MainActor
final class AppWindowController {
    private var onboardingWindow: NSWindow?
    private var overlayWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func showOnboarding(for appState: AppState) {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let viewController = NSHostingController(
            rootView: PermissionsOnboardingView().environment(appState)
        )
        let window = NSWindow(contentViewController: viewController)
        window.title = "Welcome to SwiftDictate"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 440, height: 520))
        window.center()
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
    }

    func dismissOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func showRecordingOverlay(for appState: AppState) {
        guard overlayWindow == nil else { return }

        let viewController = NSHostingController(
            rootView: RecordingOverlayView().environment(appState)
        )
        let window = RecordingOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.center()
        window.orderFrontRegardless()
        overlayWindow = window
    }

    func dismissRecordingOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
    }

    func showSettings(for appState: AppState) {
        if let settingsWindow {
            NSApp.activate()
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
            return
        }

        let viewController = NSHostingController(
            rootView: SettingsView().environment(appState)
        )
        let window = NSWindow(contentViewController: viewController)
        window.title = "SwiftDictate Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 380))
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        settingsWindow = window
    }
}

private final class RecordingOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
