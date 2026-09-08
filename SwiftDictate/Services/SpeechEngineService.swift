import Speech
import AVFoundation
import Foundation

enum SpeechEngineError: Error, Equatable, LocalizedError {
    case transcriberNotInitialized
    case modelDownloadFailed
    case analyzerStartFailed
    case inputStreamNotReady
    case localeNotSupported(Locale)
    case formatMismatch

    var errorDescription: String? {
        switch self {
        case .transcriberNotInitialized:
            "Speech transcriber has not been set up."
        case .modelDownloadFailed:
            "Failed to download the speech recognition model."
        case .analyzerStartFailed:
            "Failed to start speech analyzer."
        case .inputStreamNotReady:
            "Audio input stream is not ready."
        case .localeNotSupported(let locale):
            "The locale \"\(locale.identifier(.bcp47))\" is not supported for speech recognition."
        case .formatMismatch:
            "Audio format does not match speech analyzer requirements."
        }
    }
}

final class SpeechEngineService: @unchecked Sendable {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?
    private var analyzerFormat: AVAudioFormat?

    var isReady = false
    var isRunning = false
    var isSettingUp = false
    var downloadProgress: Progress?
    var modelState: ModelState = .unknown

    private var resultContinuation: AsyncStream<TranscriptionResult>.Continuation?
    private var _resultsStream: AsyncStream<TranscriptionResult>?

    enum ModelState {
        case unknown
        case downloading
        case ready
        case failed(Error)
    }

    deinit {
        MainActor.assumeIsolated {
            stopAnalysis()
        }
    }

    func supportedLocale(for locale: Locale) async -> Locale? {
        if let equivalent = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            return equivalent
        }

        // Locale.current can include user preference extensions such as
        // `en-US-u-rg-ltzzzz`. Speech does not currently treat those as
        // equivalent to the underlying language locale, so retry without the
        // extensions before falling back to the closest supported language.
        let languageLocale = Locale(identifier: locale.language.maximalIdentifier)
        if let equivalent = await SpeechTranscriber.supportedLocale(
            equivalentTo: languageLocale
        ) {
            return equivalent
        }

        let supportedLocales = await SpeechTranscriber.supportedLocales
        return Self.closestSupportedLocale(for: locale, from: supportedLocales)
    }

    static func closestSupportedLocale(
        for locale: Locale,
        from supportedLocales: [Locale]
    ) -> Locale? {
        let languageCode = locale.language.languageCode
        let region = locale.language.region

        return supportedLocales.first {
            $0.language.languageCode == languageCode && $0.language.region == region
        } ?? supportedLocales.first {
            $0.language.languageCode == languageCode
        }
    }

    @MainActor
    func setupTranscriber(locale: Locale) async throws {
        guard !isReady, !isSettingUp else { return }
        guard let supportedLocale = await supportedLocale(for: locale) else {
            throw SpeechEngineError.localeNotSupported(locale)
        }

        isSettingUp = true
        defer { isSettingUp = false }

        let createdTranscriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .progressiveTranscription
        )
        transcriber = createdTranscriber

        let createdAnalyzer = SpeechAnalyzer(modules: [createdTranscriber])
        analyzer = createdAnalyzer

        do {
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [createdTranscriber])
            guard let format else {
                throw SpeechEngineError.formatMismatch
            }
            analyzerFormat = format

            let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
            inputBuilder = builder

            try await createdAnalyzer.start(inputSequence: stream)
            isReady = true
        } catch {
            inputBuilder?.finish()
            inputBuilder = nil
            analyzerFormat = nil
            analyzer = nil
            transcriber = nil
            isReady = false
            throw error
        }
    }

    func downloadModelIfNeeded(for locale: Locale) async throws {
        guard let supportedLocale = await supportedLocale(for: locale) else {
            throw SpeechEngineError.localeNotSupported(locale)
        }

        let tempTranscriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .progressiveTranscription
        )

        // Asking AssetInventory for an installation request also reserves the
        // locale when its assets are already installed. Checking only
        // `installedLocales` skips that required reservation.
        guard let downloader = try await AssetInventory.assetInstallationRequest(
            supporting: [tempTranscriber]
        ) else {
            modelState = .ready
            return
        }

        modelState = .downloading
        downloadProgress = downloader.progress

        do {
            try await downloader.downloadAndInstall()
            modelState = .ready
            downloadProgress = nil
        } catch {
            modelState = .failed(error)
            downloadProgress = nil
            throw SpeechEngineError.modelDownloadFailed
        }
    }

    func startAnalysis() throws {
        guard isReady, let _ = inputBuilder else {
            throw SpeechEngineError.inputStreamNotReady
        }

        guard let transcriber else {
            throw SpeechEngineError.transcriberNotInitialized
        }

        isRunning = true

        recognizerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isRunning = false
                self.finishResultsStream()
            }

            do {
                for try await result in transcriber.results {
                    guard !Task.isCancelled else { break }

                    let transcriptionResult = TranscriptionResult(
                        text: String(result.text.characters),
                        isFinal: result.isFinal
                    )

                    self.resultContinuation?.yield(transcriptionResult)
                }
            } catch {
                if !(error is CancellationError) {
                    self.modelState = .failed(error)
                }
            }
        }
    }

    func feedAudioBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let inputBuilder, let analyzerFormat else {
            throw SpeechEngineError.inputStreamNotReady
        }

        let sourceFormat = buffer.format

        let converted: AVAudioPCMBuffer
        if sourceFormat.commonFormat == analyzerFormat.commonFormat,
           sourceFormat.sampleRate == analyzerFormat.sampleRate,
           sourceFormat.channelCount == analyzerFormat.channelCount {
            converted = buffer
        } else {
            guard let converter = AVAudioConverter(from: sourceFormat, to: analyzerFormat),
                  let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: analyzerFormat,
                    frameCapacity: AVAudioFrameCount(
                        Double(buffer.frameLength) * analyzerFormat.sampleRate / sourceFormat.sampleRate
                    )
                  ) else {
                throw SpeechEngineError.formatMismatch
            }

            var hasSuppliedInput = false
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                guard !hasSuppliedInput else {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                hasSuppliedInput = true
                outStatus.pointee = .haveData
                return buffer
            }

            let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            if status == .error || error != nil {
                throw SpeechEngineError.formatMismatch
            }

            converted = outputBuffer
        }

        let input = AnalyzerInput(buffer: converted)
        inputBuilder.yield(input)
    }

    func finalizeResults() async throws {
        guard let analyzer else {
            throw SpeechEngineError.analyzerStartFailed
        }

        try await analyzer.finalizeAndFinishThroughEndOfInput()
    }

    func stopAnalysis() {
        isRunning = false
        recognizerTask?.cancel()
        recognizerTask = nil
        finishResultsStream()
    }

    func finishInput() {
        inputBuilder?.finish()
    }

    func resetForNewSession() {
        stopAnalysis()
        inputBuilder?.finish()
        inputBuilder = nil
        isRunning = false
        isReady = false
        transcriber = nil
        analyzer = nil
        analyzerFormat = nil
    }

    func results() -> AsyncStream<TranscriptionResult> {
        if let existing = _resultsStream {
            return existing
        }
        let stream = AsyncStream<TranscriptionResult> { continuation in
            self.resultContinuation = continuation
        }
        _resultsStream = stream
        return stream
    }

    func cancel() {
        resetForNewSession()
    }

    private func finishResultsStream() {
        resultContinuation?.finish()
        resultContinuation = nil
        _resultsStream = nil
    }
}
