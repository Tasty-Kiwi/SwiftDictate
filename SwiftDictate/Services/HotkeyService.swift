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

    private(set) var globalMonitorActive = false

    var isMonitoring: Bool {
        globalMonitor != nil || localMonitor != nil
    }

    func start() {
        guard !isMonitoring else { return }

        let hasAX = AXIsProcessTrusted()
        print("[SwiftDictate] Hotkey starting — accessibility trusted: \(hasAX)")

        let matching: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: matching) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        globalMonitorActive = globalMonitor != nil

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: matching) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        print("[SwiftDictate] Hotkey monitoring started — \(self.configuration.displayName) (keyCode: \(self.configuration.keyCode)) — global: \(self.globalMonitor != nil) local: \(self.localMonitor != nil)")

        if globalMonitor == nil {
            print("[SwiftDictate] WARNING: Global monitor failed — accessibility trusted: \(hasAX). Hotkey only works when app is focused.")
        }

        logger.info("Hotkey monitoring started with \(self.configuration.displayName) — global: \(self.globalMonitorActive)")
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
        globalMonitorActive = false
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

        let eventModifiers = normalizedModifiers(for: event)
        let configModifiers = configuration.modifiers.intersection(.deviceIndependentFlagsMask)

        if eventModifiers != configModifiers {
            print("[SwiftDictate] Hotkey keyCode match but modifier mismatch — event: \(eventModifiers.rawValue) config: \(configModifiers.rawValue)")
        }

        guard eventModifiers == configModifiers else { return }

        switch event.type {
        case .keyDown:
            if !isPressed {
                isPressed = true
                lastPressTime = Date()
                print("[SwiftDictate] Hotkey pressed: \(self.configuration.displayName)")
                onHotkeyPressed?()
            }

        case .keyUp:
            if isPressed {
                isPressed = false
                print("[SwiftDictate] Hotkey released: \(self.configuration.displayName)")
                onHotkeyReleased?()
            }

        case .flagsChanged:
            guard let selfFlag = modifierFlag(for: event.keyCode) else { return }
            let flagPresent = event.modifierFlags.contains(selfFlag)

            if flagPresent && !isPressed {
                isPressed = true
                lastPressTime = Date()
                print("[SwiftDictate] Hotkey pressed: \(self.configuration.displayName)")
                onHotkeyPressed?()
            } else if !flagPresent && isPressed {
                isPressed = false
                print("[SwiftDictate] Hotkey released: \(self.configuration.displayName)")
                onHotkeyReleased?()
            }

        default:
            break
        }
    }

    private func normalizedModifiers(for event: NSEvent) -> NSEvent.ModifierFlags {
        let raw = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers = raw
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
