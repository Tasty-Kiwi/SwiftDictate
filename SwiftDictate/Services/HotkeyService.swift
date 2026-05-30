import AppKit
import Foundation
import os

final class HotkeyService {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isPressed = false
    private var lastPressTime: Date = .distantPast

    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    var configuration: HotkeyConfiguration = .default

    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "HotkeyService"
    )

    var isMonitoring: Bool {
        globalMonitor != nil && localMonitor != nil
    }

    func start() {
        guard !isMonitoring else { return }

        let matching: NSEvent.EventTypeMask = [.keyDown, .keyUp]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: matching) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: matching) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        logger.info("Hotkey monitoring started with \(self.configuration.displayName)")
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitor = nil
        localMonitor = nil
        isPressed = false

        logger.info("Hotkey monitoring stopped")
    }

    func updateConfiguration(_ config: HotkeyConfiguration) {
        let wasMonitoring = isMonitoring
        if wasMonitoring { stop() }
        configuration = config
        if wasMonitoring { start() }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard event.keyCode == configuration.keyCode else { return }

        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let configModifiers = configuration.modifiers.intersection(.deviceIndependentFlagsMask)

        guard eventModifiers == configModifiers else { return }

        switch event.type {
        case .keyDown:
            if !isPressed {
                isPressed = true
                lastPressTime = Date()
                logger.debug("Hotkey pressed: \(self.configuration.displayName)")
                onHotkeyPressed?()
            }

        case .keyUp:
            if isPressed {
                isPressed = false
                logger.debug("Hotkey released: \(self.configuration.displayName)")
                onHotkeyReleased?()
            }

        default:
            break
        }
    }
}
