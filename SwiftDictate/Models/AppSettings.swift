import Foundation

@Observable
final class AppSettings {
    private let defaults: UserDefaults

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
    var restoreClipboardAfterPaste: Bool {
        didSet { defaults.set(restoreClipboardAfterPaste, forKey: Keys.restoreClipboardAfterPaste) }
    }
    var enableSmartCleanup: Bool {
        didSet { defaults.set(enableSmartCleanup, forKey: Keys.enableSmartCleanup) }
    }
    var preferredLocaleIdentifier: String {
        didSet { defaults.set(preferredLocaleIdentifier, forKey: Keys.preferredLocaleIdentifier) }
    }

    var recordingMode: RecordingMode {
        get { RecordingMode(rawValue: recordingModeRaw) ?? .toggle }
        set { recordingModeRaw = newValue.rawValue }
    }

    var preferredLocale: Locale {
        Locale(identifier: preferredLocaleIdentifier)
    }

    init(defaults: UserDefaults = .standard, locale: Locale = .current) {
        self.defaults = defaults
        defaults.register(defaults: Defaults.registrationValues(locale: locale))

        self.recordingModeRaw = defaults.string(forKey: Keys.recordingMode)
            ?? Defaults.recordingModeRaw
        self.enableFoundationModels = defaults.object(forKey: Keys.enableFoundationModels)
            as? Bool ?? Defaults.enableFoundationModels
        self.enablePunctuationRestoration = defaults.object(forKey: Keys.enablePunctuationRestoration)
            as? Bool ?? Defaults.enablePunctuationRestoration
        self.enableGrammarCorrection = defaults.object(forKey: Keys.enableGrammarCorrection)
            as? Bool ?? Defaults.enableGrammarCorrection
        self.autoInsertText = defaults.object(forKey: Keys.autoInsertText)
            as? Bool ?? Defaults.autoInsertText
        self.restoreClipboardAfterPaste = defaults.object(forKey: Keys.restoreClipboardAfterPaste)
            as? Bool ?? Defaults.restoreClipboardAfterPaste
        self.enableSmartCleanup = defaults.object(forKey: Keys.enableSmartCleanup)
            as? Bool ?? Defaults.enableSmartCleanup
        self.preferredLocaleIdentifier = defaults.string(forKey: Keys.preferredLocaleIdentifier)
            ?? Defaults.preferredLocaleIdentifier(for: locale)
    }

    private enum Keys {
        static let recordingMode = "recordingMode"
        static let enableFoundationModels = "enableFoundationModels"
        static let enablePunctuationRestoration = "enablePunctuationRestoration"
        static let enableGrammarCorrection = "enableGrammarCorrection"
        static let enableSmartCleanup = "enableSmartCleanup"
        static let autoInsertText = "autoInsertText"
        // Keep the persisted key for compatibility with existing installations.
        static let restoreClipboardAfterPaste = "clearClipboardAfterPaste"
        static let preferredLocaleIdentifier = "preferredLocaleIdentifier"
    }

    private enum Defaults {
        static let recordingModeRaw = RecordingMode.toggle.rawValue
        static let enableFoundationModels = true
        static let enablePunctuationRestoration = true
        static let enableGrammarCorrection = true
        static let enableSmartCleanup = true
        static let autoInsertText = true
        static let restoreClipboardAfterPaste = true

        static func preferredLocaleIdentifier(for locale: Locale) -> String {
            locale.identifier(.bcp47)
        }

        static func registrationValues(locale: Locale) -> [String: Any] {
            [
                Keys.recordingMode: recordingModeRaw,
                Keys.enableFoundationModels: enableFoundationModels,
                Keys.enablePunctuationRestoration: enablePunctuationRestoration,
                Keys.enableGrammarCorrection: enableGrammarCorrection,
                Keys.enableSmartCleanup: enableSmartCleanup,
                Keys.autoInsertText: autoInsertText,
                Keys.restoreClipboardAfterPaste: restoreClipboardAfterPaste,
                Keys.preferredLocaleIdentifier: preferredLocaleIdentifier(for: locale),
            ]
        }
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
