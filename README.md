# SwiftDictate

SwiftDictate is a fully native, local macOS menu bar application for speech recognition and dictation powered by Apple Speech and Apple Intelligence (FoundationModels).

It provides real-time dictation, intelligent transcript post-processing (cleanup, grammar correction, punctuation restoration, custom vocabulary matching, and programming directives), and automatic text insertion into any frontmost application.

---

## Key Features

- **100% On-Device & Private**: All speech recognition and language processing runs locally on Apple Silicon. No third-party servers, cloud services, or data tracking.
- **Menu Bar UI**: Runs quietly in the macOS menu bar without taking up space in your Dock.
- **Flexible Dictation Modes**:
  - **Push-to-Talk**: Hold hotkey to record, release to transcribe and insert.
  - **Toggle**: Press hotkey to start recording, press again to stop.
- **Apple Intelligence Integration**:
  - Smart filler word removal and self-correction cleanup.
  - Punctuation restoration and automatic capitalization.
  - Grammar refinement without changing intent or tone.
  - Custom system prompt instructions.
  - Optional **Private Cloud Compute** fallback support.
- **Custom Dictionary**: Define specialized terminology, names, or technical jargon to ensure exact spelling and capitalization during transcription post-processing.
- **Programming Directives**: Voice macros for developer workflows (e.g., spoken "camel case account record" automatically transforms into `accountRecord`, "snake case user id" transforms into `user_id`).
- **Direct App Text Insertion**: Automatically pastes transcribed text into whatever text field or application is currently focused, with original clipboard content auto-restored.
- **Transcript History**: Local history store with configurable retention limits to review, search, copy, or manage past dictation records.

---

## Requirements

- **macOS**: Target macOS 15.0+ / 26.5+ (Apple Silicon recommended for local FoundationModels / Apple Intelligence)
- **Xcode**: Xcode 16+ or newer supporting Swift 6
- **Permissions**:
  - **Microphone**: For audio recording.
  - **Speech Recognition**: For Apple Speech transcribing models.
  - **Accessibility**: For global hotkey monitoring (`NSEvent`) and text paste simulation (`CGEvent`).

---

## Getting Started

### Building & Running

Open `SwiftDictate.xcodeproj` in Xcode or build via `xcodebuild`:

```bash
# Build SwiftDictate
xcodebuild -project SwiftDictate.xcodeproj -scheme SwiftDictate -destination 'platform=macOS' build

# Run Unit Tests
xcodebuild -project SwiftDictate.xcodeproj -scheme SwiftDictate -destination 'platform=macOS' test
```

### Initial Permissions Setup

When running SwiftDictate for the first time:
1. Grant **Microphone** access when prompted.
2. Grant **Speech Recognition** access when prompted.
3. Grant **Accessibility** access in **System Settings > Privacy & Security > Accessibility** to enable global hotkey handling and automatic text insertion.

---

## Architecture Overview

SwiftDictate is built with Swift 6 and SwiftUI using an `@Observable` unidirectional service model managed by `AppState`:

```
SwiftDictateApp (@main, MenuBarExtra)
    └── AppState (@Observable, @MainActor) — Central State Container
         ├── PermissionsService      — System permission checks (Mic, Accessibility, Speech)
         ├── AudioCaptureService     — AVAudioEngine real-time PCM audio stream
         ├── SpeechEngineService     — SpeechAnalyzer & SpeechTranscriber integration
         ├── FoundationModelsService — SystemLanguageModel / LanguageModelSession integration
         ├── TextInsertionService    — Clipboard operations & CGEvent key simulation
         ├── HotkeyService           — Global & local NSEvent hotkey listeners
         └── TranscriptHistoryStore  — Local JSON-backed history persistence
```

---

## Usage Guide

1. **Start Dictating**: Press the configured hotkey (default: **Right Option** or your custom shortcut) to begin recording audio.
2. **Visual Indicator**: The menu bar icon changes state to reflect audio capture and processing. An optional overlay view shows real-time live transcription.
3. **Automatic Insertion**: Once recording finishes, the transcript is processed with enabled Apple Intelligence rules and pasted into your active cursor position.
4. **Settings & Customization**: Click the menu bar icon to access Settings:
   - **General**: Choose recording mode, preferred locale, and hotkey configuration.
   - **Processing**: Toggle smart cleanup, grammar, punctuation restoration, custom vocabulary, and programming directives.
   - **History**: View past dictations and set retention rules.

---

## License

SwiftDictate is released under the [MIT License](LICENSE).
