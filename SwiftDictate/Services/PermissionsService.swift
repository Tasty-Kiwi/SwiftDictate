import AVFoundation
import AppKit
import ApplicationServices
import Speech
import Foundation
import os

enum Permission: String, CaseIterable {
    case microphone
    case accessibility
    case speechRecognition

    var displayName: String {
        switch self {
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        case .speechRecognition: "Speech Recognition"
        }
    }

    var description: String {
        switch self {
        case .microphone: "Required to capture your voice for transcription."
        case .accessibility: "Required to insert transcribed text into other applications."
        case .speechRecognition: "Required for on-device speech-to-text transcription."
        }
    }
}

@Observable
final class PermissionsService {
    var microphoneAuthorized = false
    var accessibilityTrusted = false
    var speechRecognitionAuthorized = false

    private let logger = Logger(
        subsystem: "net.tastykiwi.SwiftDictate",
        category: "PermissionsService"
    )

    var allGranted: Bool {
        microphoneAuthorized && accessibilityTrusted
    }

    var missingPermissions: [Permission] {
        var result: [Permission] = []
        if !microphoneAuthorized { result.append(.microphone) }
        if !accessibilityTrusted { result.append(.accessibility) }
        return result
    }

    func refreshAll() {
        microphoneAuthorized = checkMicrophone()
        accessibilityTrusted = checkAccessibilityTrust()
        speechRecognitionAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized

        logger.info("Permissions refreshed — mic:\(self.microphoneAuthorized) ax:\(self.accessibilityTrusted) speech:\(self.speechRecognitionAuthorized)")
    }

    private func checkMicrophone() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneAuthorized = granted
        return granted
    }

    func checkAccessibilityTrust() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focused
        )
        if result == .success {
            logger.info("AXIsProcessTrusted returned false but AX API call succeeded -- treating as trusted")
            return true
        }
        if result == .apiDisabled {
            logger.info("AX API returned apiDisabled -- accessibility access is blocked")
            return false
        }

        logger.info("AX API returned error: \(result.rawValue)")
        return false
    }

    func requestAccessibility() {
        logger.info("Prompting user for accessibility permission")

        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options = [promptKey: true] as CFDictionary

        AXIsProcessTrustedWithOptions(options)

        UserDefaults.standard.set(true, forKey: "AXPrompted")

        accessibilityTrusted = checkAccessibilityTrust()
    }

    func pollAccessibilityUntilTrusted() async {
        for attempt in 1...15 {
            accessibilityTrusted = checkAccessibilityTrust()
            if accessibilityTrusted {
                logger.info("Accessibility granted after \(attempt) poll(s)")
                return
            }

            logger.debug("Poll attempt \(attempt): accessibility not yet trusted")

            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
        }

        logger.warning("Accessibility polling exhausted after 15s, still not trusted")
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)

        Task {
            await pollAccessibilityUntilTrusted()
        }
    }

    func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let authorized = status == .authorized
                self.speechRecognitionAuthorized = authorized
                continuation.resume(returning: authorized)
            }
        }
    }
}
