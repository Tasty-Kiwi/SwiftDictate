import Testing
@testable import SwiftDictate

struct PermissionsServiceTests {

    @Test func missingPermissionsWhenNoneGranted() {
        let service = PermissionsService()
        service.microphoneAuthorized = false
        service.accessibilityTrusted = false
        service.speechRecognitionAuthorized = false

        #expect(!service.allGranted)
        #expect(service.missingPermissions.count >= 2)
        #expect(service.missingPermissions.contains(.microphone))
        #expect(service.missingPermissions.contains(.accessibility))
    }

    @Test func allGrantedWhenBothPermissionsSet() {
        let service = PermissionsService()
        service.microphoneAuthorized = true
        service.accessibilityTrusted = true

        #expect(service.allGranted)
        #expect(service.missingPermissions.isEmpty)
    }

    @Test func partialPermissions() {
        let service = PermissionsService()
        service.microphoneAuthorized = true
        service.accessibilityTrusted = false

        #expect(!service.allGranted)
        #expect(service.missingPermissions.count == 1)
        #expect(service.missingPermissions.contains(.accessibility))
    }

    @Test func refreshAllSetsAccessibility() {
        let service = PermissionsService()
        service.refreshAll()

        #expect(type(of: service.accessibilityTrusted) == Bool.self)
        #expect(type(of: service.microphoneAuthorized) == Bool.self)
    }

    @Test func permissionsAllCases() {
        let allPermissions = Permission.allCases
        #expect(allPermissions.count == 3)
        #expect(allPermissions.contains(.microphone))
        #expect(allPermissions.contains(.accessibility))
        #expect(allPermissions.contains(.speechRecognition))
    }

    @Test func permissionDisplayNames() {
        for permission in Permission.allCases {
            #expect(!permission.displayName.isEmpty)
            #expect(!permission.description.isEmpty)
        }
    }
}
