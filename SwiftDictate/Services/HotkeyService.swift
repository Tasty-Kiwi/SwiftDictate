import AppKit
import Foundation
import os

struct HotkeyEvent {
    enum Kind {
        case keyDown
        case keyUp
        case flagsChanged
    }

    let kind: Kind
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
}

final class HotkeyService {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    var configuration: HotkeyConfiguration = .default
    private(set) var isHotkeyPressed = false

    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "HotkeyService"
    )

    var isMonitoring: Bool {
        globalMonitor != nil || localMonitor != nil
    }

    func start() {
        guard !isMonitoring else { return }

        let matching: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: matching) { [weak self] event in
            self?.process(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: matching) { [weak self] event in
            self?.process(event)
            return event
        }

        if globalMonitor == nil {
            logger.warning("Global hotkey monitor unavailable; hotkey works only while SwiftDictate is focused")
        }
        logger.info("Hotkey monitoring started with \(self.configuration.displayName)")
    }

    func stop() {
        guard isMonitoring else { return }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitor = nil
        localMonitor = nil
        isHotkeyPressed = false

        logger.info("Hotkey monitoring stopped")
    }

    func updateConfiguration(_ config: HotkeyConfiguration) {
        let wasMonitoring = isMonitoring
        if wasMonitoring { stop() }
        configuration = config
        if wasMonitoring { start() }
    }

    func process(_ event: HotkeyEvent) {
        guard event.keyCode == configuration.keyCode,
              normalizedModifiers(for: event) == configuration.modifiers.intersection(.deviceIndependentFlagsMask) else {
            return
        }

        switch event.kind {
        case .keyDown:
            press()
        case .keyUp:
            release()
        case .flagsChanged:
            guard let selfFlag = modifierFlag(for: event.keyCode) else { return }
            event.modifiers.contains(selfFlag) ? press() : release()
        }
    }

    private func process(_ event: NSEvent) {
        let kind: HotkeyEvent.Kind
        switch event.type {
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        case .flagsChanged: kind = .flagsChanged
        default: return
        }

        process(HotkeyEvent(kind: kind, keyCode: event.keyCode, modifiers: event.modifierFlags))
    }

    private func press() {
        guard !isHotkeyPressed else { return }
        isHotkeyPressed = true
        logger.debug("Hotkey pressed: \(self.configuration.displayName)")
        onHotkeyPressed?()
    }

    private func release() {
        guard isHotkeyPressed else { return }
        isHotkeyPressed = false
        logger.debug("Hotkey released: \(self.configuration.displayName)")
        onHotkeyReleased?()
    }

    private func normalizedModifiers(for event: HotkeyEvent) -> NSEvent.ModifierFlags {
        var modifiers = event.modifiers.intersection(.deviceIndependentFlagsMask)
        if let selfModifier = modifierFlag(for: event.keyCode) {
            modifiers.remove(selfModifier)
        }
        return modifiers
    }

    private func modifierFlag(for keyCode: UInt16) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 54, 55: return .command
        case 56, 60: return .shift
        case 58, 61: return .option
        case 59: return .control
        case 63: return .function
        default: return nil
        }
    }
}
