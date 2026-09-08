import Testing
@testable import SwiftDictate

struct ProgrammingDirectiveProcessorTests {
    @Test func convertsOnlyTheDirectiveSpan() {
        let examples = [
            ("camel case account record", "accountRecord"),
            ("snake case account record", "account_record"),
            (
                "Please store snake case preferred display name before showing the profile.",
                "Please store preferred_display_name before showing the profile."
            ),
            (
                "Send camel case customer account to the API after validation.",
                "Send customerAccount to the API after validation."
            ),
            ("Call camel case fetch profile, then return.", "Call fetchProfile, then return."),
            ("Use snake case Agents SDK client.", "Use agents_sdk_client."),
        ]

        for (input, expected) in examples {
            #expect(ProgrammingDirectiveProcessor.process(input) == expected)
        }
    }

    @Test func preservesLiteralDiscussionAndExistingIdentifiers() {
        let examples = [
            "Camel case is common in Swift.",
            "I prefer camel case for identifiers.",
            "Use the existingIdentifier unchanged.",
        ]

        for input in examples {
            #expect(ProgrammingDirectiveProcessor.process(input) == input)
        }
    }
}
