# AGENTS.md — SwiftDictate

## Project summary

Fully local macOS dictation utility. Menu bar app targeting macOS 26.5 on Apple Silicon. All processing is on-device: no cloud, no OpenAI, no external servers.

## Build & test commands

```bash
# Build
xcodebuild -project SwiftDictate.xcodeproj -scheme SwiftDictate -destination 'platform=macOS' build

# Test
xcodebuild -project SwiftDictate.xcodeproj -scheme SwiftDictate -destination 'platform=macOS' test

# Clean derived data (if build cache corrupts)
rm -rf ~/Library/Developer/Xcode/DerivedData/SwiftDictate-*
```

## Architecture

```
SwiftDictateApp (@main, MenuBarExtra)
    └── AppState (@Observable, @MainActor) — root state container
         ├── PermissionsService     (mic, accessibility, speech)
         ├── AudioCaptureService    (AVAudioEngine → AsyncStream<PCM>)
         ├── SpeechEngineService    (SpeechAnalyzer + SpeechTranscriber)
         ├── FoundationModelsService (LanguageModelSession, #if canImport)
         ├── TextInsertionService   (CGEvent Unicode injection, clipboard fallback)
         ├── HotkeyService          (NSEvent global+local monitors)
         └── AppSettings            (manual UserDefaults, didSet persistence)
```

Services are `@Observable` classes owned by `AppState`. No singletons except `UserDefaults.standard` in AppSettings.

## SDK / API specifics

### SpeechAnalyzer (WWDC25/277)
- `SpeechTranscriber(locale:, preset:)` — **requires `preset:`** parameter
- Available presets: `.transcription`, `.progressiveTranscription`, `.timeIndexedProgressiveTranscription`, `.transcriptionWithAlternatives`, `.timeIndexedTranscriptionWithAlternatives`
- Option types are **singular** nouns: `TranscriptionOption`, `ReportingOption`, `ResultAttributeOption` (not plural)
- `SpeechTranscriber.supportedLocales` / `.installedLocales` are `async` static properties
- Model download via `AssetInventory.assetInstallationRequest(supporting:)` — import `Speech`, possibly `AssetManagement` framework
- `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` is `async`
- Audio fed via `AsyncStream<AnalyzerInput>` through `inputBuilder.yield(AnalyzerInput(buffer:))`
- Results consumed via `transcriber.results` — an `AsyncSequence`
- Finalize with `analyzer.finalizeAndFinishThroughEndOfInput()`

### FoundationModels (WWDC25/286, 301)
- **Must guard with `#if canImport(FoundationModels)`** — the framework may not be in all SDKs
- `SystemLanguageModel.availability` returns `.available` or `.unavailable(reason)`
- `LanguageModelSession.GenerationError` has many cases: `.exceededContextWindowSize`, `.unsupportedLanguageOrLocale`, `.assetsUnavailable`, `.guardrailViolation`, `.unsupportedGuide`, `.decodingFailure`, `.rateLimited`, `.concurrentRequests`, `.refusal` — **switch must be exhaustive**

### Enums with SDK naming conflicts
- `SpeechEngineService.ModelState` has `.ready`, `.downloading` cases which conflict with `AssetInventory.Status` and other SDK enums. Renamed uniquely to avoid ambiguity.
- Always qualify ambiguous enum cases fully or use unique naming for custom enums that share case names with SDK types.

## Entitlements & Info.plist

- **Sandbox: DISABLED** (`ENABLE_APP_SANDBOX = NO`) — required for CGEvent injection and accessibility
- `LSUIElement = YES` — menu bar only, no Dock icon
- `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` set in build settings
- Entitlements file at `SwiftDictate/SwiftDictate.entitlements` — referenced via `CODE_SIGN_ENTITLEMENTS`

## Project file quirks

- **PBXFileSystemSynchronizedRootGroup** — Xcode auto-discovers files in `SwiftDictate/` and `SwiftDictateTests/`. No manual file references needed.
- Object version 77 (Xcode 16+/26+ format)
- The test target was added manually to `project.pbxproj`. If test discovery fails, verify:
  - `PBXNativeTarget` for `SwiftDictateTests` has `productType = com.apple.product-type.bundle.unit-test`
  - `TestTargetID` in `TargetAttributes` points to `866174D32FCB1DAD006009E6` (main target)
  - `TEST_HOST` build setting points to `$(BUILT_PRODUCTS_DIR)/SwiftDictate.app/Contents/MacOS/SwiftDictate`

## Testing

- Uses **Swift Testing** framework (`import Testing`), not XCTest
- Test target: `SwiftDictateTests/` — same PBXFileSystemSynchronizedRootGroup auto-discovery
- Test files need explicit imports: `import Foundation`, `import AppKit`, `import AVFoundation` as needed (not inherited from main target)
- `@testable import SwiftDictate` gives access to internal types
- Error enums must conform to `Equatable` for `#expect(throws:)` macro

## Known compiler patterns

- `@Observable` + `@AppStorage` **conflicts** in Swift 6 — use manual `UserDefaults` with `didSet` and `init()` reading
- SwiftUI `App.init()` cannot use `Task {}` that captures `self` — use `.task {}` on content view or `@NSApplicationDelegateAdaptor`
- `@Observable` auto-synthesizes `_$observationRegistrar` — avoid manually declaring properties with `_` prefix
- `#canImport(FoundationModels)` for conditional compilation; fallback code paths must compile without that framework

## Key file locations

| Layer | Path |
|-------|------|
| Entry point | `SwiftDictate/SwiftDictateApp.swift` |
| Root state | `SwiftDictate/AppState.swift` |
| Services | `SwiftDictate/Services/` |
| Models | `SwiftDictate/Models/` |
| Views | `SwiftDictate/Views/` |
| Utilities | `SwiftDictate/Utilities/` |
| Entitlements | `SwiftDictate/SwiftDictate.entitlements` |
| Tests | `SwiftDictateTests/` |

## Service coupling

- `AppState` owns all services and wires them together
- `SpeechEngineService` depends on `SpeechTranscriber` / `SpeechAnalyzer` (Speech framework)
- `FoundationModelsService` degrades gracefully when Apple Intelligence is off
- `HotkeyService` uses `NSEvent.addGlobalMonitorForEvents` (requires accessibility permission)
- `TextInsertionService` uses CGEvent Unicode injection; `NSPasteboard` as fallback
