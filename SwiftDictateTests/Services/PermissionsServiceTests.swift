import Testing
@testable import SwiftDictate

struct PermissionsServiceTests {

    @Test func missingPermissionsIncludesEveryRequiredPermission() {
        let service = PermissionsService()
        service.microphoneAuthorized = false
        service.accessibilityTrusted = false
        service.speechRecognitionAuthorized = false

        #expect(!service.allGranted)
        #expect(service.missingPermissions == [.microphone, .accessibility, .speechRecognition])
    }

    @Test func allGrantedRequiresMicrophoneAccessibilityAndSpeechRecognition() {
        let service = PermissionsService()
        service.microphoneAuthorized = true
        service.accessibilityTrusted = true

        #expect(!service.allGranted)
        #expect(service.missingPermissions == [.speechRecognition])

        service.speechRecognitionAuthorized = true
        #expect(service.allGranted)
        #expect(service.missingPermissions.isEmpty)
    }
}
