import AppKit
import Testing

@testable import SwiftDictate

@MainActor
struct AppWindowControllerTests {
    @Test func settingsWindowCanBeClosedAndReopened() async throws {
        let controller = AppWindowController()
        let appState = AppState()

        controller.showSettings(for: appState)
        let firstWindow = try #require(
            NSApp.windows.first { $0.title == "SwiftDictate Settings" }
        )
        firstWindow.close()

        await Task.yield()

        controller.showSettings(for: appState)
        let reopenedWindow = try #require(
            NSApp.windows.first { $0.title == "SwiftDictate Settings" && $0.isVisible }
        )

        #expect(reopenedWindow !== firstWindow)
        reopenedWindow.close()
    }
}
