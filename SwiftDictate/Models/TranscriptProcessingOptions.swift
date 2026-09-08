import Foundation

struct TranscriptProcessingOptions: Equatable, Sendable {
    let foundationModelsEnabled: Bool
    let smartCleanupEnabled: Bool
    let punctuationRestorationEnabled: Bool
    let grammarCorrectionEnabled: Bool
    let programmingDirectivesEnabled: Bool
    let customWords: [String]

    var requiresModelProcessing: Bool {
        foundationModelsEnabled && (
            smartCleanupEnabled
                || punctuationRestorationEnabled
                || grammarCorrectionEnabled
                || !customWords.isEmpty
        )
    }

    var requiresProcessing: Bool {
        requiresModelProcessing || programmingDirectivesEnabled
    }
}

enum IntelligenceProviderPreference: String, Equatable, Sendable {
    case onDevice
    case privateCloudPreferred
}

enum TranscriptModelProvider: Equatable, Sendable {
    case onDevice
    case privateCloudCompute
}

enum PrivateCloudComputeStatus: Equatable, Sendable {
    case disabledByFeatureFlag
    case unsupportedOperatingSystem
    case available
    case deviceNotEligible
    case systemNotReady
    case unavailable

    var isAvailable: Bool { self == .available }

    var explanation: String {
        switch self {
        case .disabledByFeatureFlag:
            "Private Cloud Compute is disabled in this build."
        case .unsupportedOperatingSystem:
            "Requires macOS 27 or later."
        case .available:
            "Available. Processing can use Apple's Private Cloud Compute."
        case .deviceNotEligible:
            "This device or developer entitlement is not eligible for Private Cloud Compute."
        case .systemNotReady:
            "Private Cloud Compute is not ready on this Mac."
        case .unavailable:
            "Private Cloud Compute is currently unavailable."
        }
    }
}
