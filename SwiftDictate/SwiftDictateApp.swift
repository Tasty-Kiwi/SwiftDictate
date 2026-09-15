import AppKit
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
            MenuBarMicrophoneIcon(activity: activity)
                .accessibilityLabel(activity.accessibilityDescription)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarMicrophoneIcon: View {
    let activity: MenuBarActivity

    @ViewBuilder
    var body: some View {
        if activity == .none {
            Image(systemName: activity.microphoneSymbolName)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.primary)
        } else {
            Image(nsImage: activeMenuBarImage)
                .renderingMode(.original)
        }
    }

    private var activeMenuBarImage: NSImage {
        guard let symbol = NSImage(
            systemSymbolName: activity.microphoneSymbolName,
            accessibilityDescription: activity.accessibilityDescription
        ) else {
            return NSImage()
        }

        let sizeConfiguration = NSImage.SymbolConfiguration(
            pointSize: 13,
            weight: .regular
        )
        let configuredSymbol = symbol.withSymbolConfiguration(sizeConfiguration) ?? symbol
        let tintedImage = NSImage(size: configuredSymbol.size, flipped: false) { rect in
            configuredSymbol.draw(in: rect)
            activity.tint.nsColor.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        tintedImage.isTemplate = false
        return tintedImage
    }
}

extension MenuBarActivityTint {
    var color: Color {
        switch self {
        case .primary: .primary
        case .red: .red
        case .yellow: .yellow
        }
    }

    var nsColor: NSColor {
        switch self {
        case .primary: .labelColor
        case .red: .systemRed
        case .yellow: .systemYellow
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
