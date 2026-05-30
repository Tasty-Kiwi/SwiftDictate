import Foundation

@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var recordingModeRaw: String {
        didSet { defaults.set(recordingModeRaw, forKey: Keys.recordingMode) }
    }
    var enableFoundationModels: Bool {
        didSet { defaults.set(enableFoundationModels, forKey: Keys.enableFoundationModels) }
    }
    var enablePunctuationRestoration: Bool {
        didSet { defaults.set(enablePunctuationRestoration, forKey: Keys.enablePunctuationRestoration) }
    }
    var enableGrammarCorrection: Bool {
        didSet { defaults.set(enableGrammarCorrection, forKey: Keys.enableGrammarCorrection) }
    }
    var autoInsertText: Bool {
        didSet { defaults.set(autoInsertText, forKey: Keys.autoInsertText) }
    }
    var enableSmartCleanup: Bool {
        didSet { defaults.set(enableSmartCleanup, forKey: Keys.enableSmartCleanup) }
    }
    var preferredLocaleIdentifier: String {
        didSet { defaults.set(preferredLocaleIdentifier, forKey: Keys.preferredLocaleIdentifier) }
    }

    var recordingMode: RecordingMode {
        get { RecordingMode(rawValue: recordingModeRaw) ?? .pushToTalk }
        set { recordingModeRaw = newValue.rawValue }
    }

    var preferredLocale: Locale {
        Locale(identifier: preferredLocaleIdentifier)
    }

    init() {
        self.recordingModeRaw = defaults.string(forKey: Keys.recordingMode)
            ?? RecordingMode.pushToTalk.rawValue
        self.enableFoundationModels = defaults.object(forKey: Keys.enableFoundationModels)
            as? Bool ?? true
        self.enablePunctuationRestoration = defaults.object(forKey: Keys.enablePunctuationRestoration)
            as? Bool ?? true
        self.enableGrammarCorrection = defaults.object(forKey: Keys.enableGrammarCorrection)
            as? Bool ?? true
        self.autoInsertText = defaults.object(forKey: Keys.autoInsertText)
            as? Bool ?? true
        self.enableSmartCleanup = defaults.object(forKey: Keys.enableSmartCleanup)
            as? Bool ?? true
        self.preferredLocaleIdentifier = defaults.string(forKey: Keys.preferredLocaleIdentifier)
            ?? Locale.current.identifier(.bcp47)

        registerDefaults()
    }

    private func registerDefaults() {
        let defaultValues: [String: Any] = [
            Keys.recordingMode: RecordingMode.pushToTalk.rawValue,
            Keys.enableFoundationModels: true,
            Keys.enablePunctuationRestoration: true,
            Keys.enableGrammarCorrection: true,
            Keys.enableSmartCleanup: true,
            Keys.autoInsertText: true,
            Keys.preferredLocaleIdentifier: Locale.current.identifier(.bcp47),
        ]
        defaults.register(defaults: defaultValues)
    }

    private enum Keys {
        static let recordingMode = "recordingMode"
        static let enableFoundationModels = "enableFoundationModels"
        static let enablePunctuationRestoration = "enablePunctuationRestoration"
        static let enableGrammarCorrection = "enableGrammarCorrection"
        static let enableSmartCleanup = "enableSmartCleanup"
        static let autoInsertText = "autoInsertText"
        static let preferredLocaleIdentifier = "preferredLocaleIdentifier"
    }

    enum RecordingMode: String, CaseIterable {
        case pushToTalk = "pushToTalk"
        case toggle = "toggle"

        var displayName: String {
            switch self {
            case .pushToTalk: "Push to Talk"
            case .toggle: "Toggle"
            }
        }

        var description: String {
            switch self {
            case .pushToTalk: "Hold hotkey to record, release to stop"
            case .toggle: "Tap hotkey to start recording, tap again to stop"
            }
        }
    }
}
