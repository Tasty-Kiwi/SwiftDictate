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
        case .speechRecognition: "Required for speech-to-text transcription."
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
        missingPermissions.isEmpty
    }

    var missingPermissions: [Permission] {
        var result: [Permission] = []
        if !microphoneAuthorized { result.append(.microphone) }
        if !accessibilityTrusted { result.append(.accessibility) }
        if !speechRecognitionAuthorized { result.append(.speechRecognition) }
        return result
    }

    func isGranted(_ permission: Permission) -> Bool {
        switch permission {
        case .microphone: microphoneAuthorized
        case .accessibility: accessibilityTrusted
        case .speechRecognition: speechRecognitionAuthorized
        }
    }

    func refreshAll() {
        let microphoneAuthorized = checkMicrophone()
        let accessibilityTrusted = checkAccessibilityTrust()
        let speechRecognitionAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized

        let didChange = self.microphoneAuthorized != microphoneAuthorized
            || self.accessibilityTrusted != accessibilityTrusted
            || self.speechRecognitionAuthorized != speechRecognitionAuthorized

        self.microphoneAuthorized = microphoneAuthorized
        self.accessibilityTrusted = accessibilityTrusted
        self.speechRecognitionAuthorized = speechRecognitionAuthorized

        if didChange {
            logger.info("Permissions refreshed — mic:\(microphoneAuthorized) ax:\(accessibilityTrusted) speech:\(speechRecognitionAuthorized)")
        }
    }

    private func checkMicrophone() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneAuthorized = granted
        return granted
    }

    private func checkAccessibilityTrust() -> Bool {
        AXIsProcessTrusted()
    }

    private func requestAccessibility() {
        logger.info("Prompting user for accessibility permission")

        // Avoid `kAXTrustedCheckOptionPrompt`: Swift 6 imports that C global as
        // mutable shared state. This is the documented value of that key.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary

        AXIsProcessTrustedWithOptions(options)

        accessibilityTrusted = checkAccessibilityTrust()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func requestSpeechRecognition() async -> Bool {
        let status = await Self.requestSpeechRecognitionAuthorization()

        let authorized = status == .authorized
        speechRecognitionAuthorized = authorized
        return authorized
    }

    /// `SFSpeechRecognizer` invokes its legacy completion handler on an arbitrary
    /// queue. Keep that callback outside this app's default MainActor isolation.
    private nonisolated static func requestSpeechRecognitionAuthorization() async
        -> SFSpeechRecognizerAuthorizationStatus
    {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Requests every permission needed to capture, transcribe, and insert dictation.
    /// Accessibility is intentionally not polled here: the user grants it in System Settings
    /// and `refreshAll()` observes the result when they return to the app.
    func requestRequiredPermissions() async {
        refreshAll()

        if !microphoneAuthorized {
            _ = await requestMicrophone()
        }
        if !speechRecognitionAuthorized {
            _ = await requestSpeechRecognition()
        }
        if !accessibilityTrusted {
            requestAccessibility()
        }

        refreshAll()
    }
}
