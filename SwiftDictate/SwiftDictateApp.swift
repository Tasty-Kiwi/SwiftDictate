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

    var body: some View {
        if activity == .none {
            Image(systemName: activity.microphoneSymbolName)
        } else {
            ZStack {
                Capsule()
                    .fill(activityColor)
                    .frame(width: 6, height: 10)
                    .offset(y: -2)

                MicrophoneCradle()
                    .stroke(activityColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 12, height: 12)

                Capsule()
                    .fill(activityColor)
                    .frame(width: 1.5, height: 4)
                    .offset(y: 5)

                Capsule()
                    .fill(activityColor)
                    .frame(width: 7, height: 1.5)
                    .offset(y: 7)
            }
            .frame(width: 16, height: 16)
        }
    }

    private var activityColor: Color {
        activity.tint == .red ? .red : .yellow
    }
}

private struct MicrophoneCradle: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY - 1))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - 1),
            control1: CGPoint(x: rect.minX, y: rect.maxY - 1),
            control2: CGPoint(x: rect.maxX, y: rect.maxY - 1)
        )
        return path
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
