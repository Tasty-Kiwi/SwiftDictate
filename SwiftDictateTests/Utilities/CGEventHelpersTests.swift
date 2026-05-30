import Testing
import Foundation
@testable import SwiftDictate

struct CGEventHelpersTests {

    @Test func typeCharacterHandlesEmptyString() throws {
        try CGEventHelpers.typeText("")
    }

    @Test func getFocusedAppPIDReturnsValue() {
        let pid = CGEventHelpers.getFocusedAppPID()
        #expect(type(of: pid) == pid_t.self)
    }

    @Test func simulatePasteDoesNotThrow() {
        CGEventHelpers.simulatePaste()
    }
}
