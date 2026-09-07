import AVFoundation
import CoreAudio
import Foundation

enum AudioCaptureError: Error, Equatable {
    case alreadyRunning
}

/// An immutable, owned copy of a buffer delivered from `AVAudioEngine`'s realtime tap.
///
/// `AVAudioPCMBuffer` is not `Sendable` and a tap only lends its buffer for the duration
/// of its callback. This wrapper copies the bytes before they cross to the main actor and
/// never mutates its buffer afterwards.
nonisolated final class CapturedAudioBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer

    init?(copying source: AVAudioPCMBuffer) {
        guard let copy = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameLength
        ) else {
            return nil
        }

        copy.frameLength = source.frameLength
        let sourceBuffers = CoreAudio.UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: source.audioBufferList)
        )
        let destinationBuffers = CoreAudio.UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else {
            return nil
        }

        for index in sourceBuffers.indices {
            let sourceBuffer = sourceBuffers[index]
            guard let sourceData = sourceBuffer.mData,
                  let destinationData = destinationBuffers[index].mData else {
                return nil
            }
            memcpy(destinationData, sourceData, Int(sourceBuffer.mDataByteSize))
        }

        buffer = copy
    }
}

nonisolated protocol AudioCapturingEngine: AnyObject {
    func startCapturing(_ handler: @escaping (CapturedAudioBuffer) -> Void) throws
    func stopCapturing()
}

private nonisolated final class SystemAudioCapturingEngine: AudioCapturingEngine {
    private let engine = AVAudioEngine()
    private let stateLock = NSLock()
    private var hasInstalledTap = false

    func startCapturing(_ handler: @escaping (CapturedAudioBuffer) -> Void) throws {
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: recordingFormat
        ) { buffer, _ in
            guard let copiedBuffer = CapturedAudioBuffer(copying: buffer) else { return }
            handler(copiedBuffer)
        }
        stateLock.withLock { hasInstalledTap = true }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            stateLock.withLock { hasInstalledTap = false }
            throw error
        }
    }

    func stopCapturing() {
        let shouldRemoveTap = stateLock.withLock { () -> Bool in
            defer { hasInstalledTap = false }
            return hasInstalledTap
        }

        if shouldRemoveTap {
            engine.inputNode.removeTap(onBus: 0)
        }
        engine.stop()
    }
}

final class AudioCaptureService: @unchecked Sendable {
    private let captureEngine: AudioCapturingEngine
    private var outputContinuation: AsyncStream<CapturedAudioBuffer>.Continuation?
    private let stateLock = NSLock()

    init(captureEngine: AudioCapturingEngine = SystemAudioCapturingEngine()) {
        self.captureEngine = captureEngine
    }

    private var _isRunning = false
    var isRunning: Bool {
        stateLock.withLock { _isRunning }
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    func start() throws -> AsyncStream<CapturedAudioBuffer> {
        let (stream, continuation) = AsyncStream<CapturedAudioBuffer>.makeStream()

        stateLock.lock()
        guard !_isRunning else {
            stateLock.unlock()
            continuation.finish()
            throw AudioCaptureError.alreadyRunning
        }
        outputContinuation = continuation
        do {
            try captureEngine.startCapturing { buffer in
                continuation.yield(buffer)
            }
            _isRunning = true
            stateLock.unlock()
            return stream
        } catch {
            outputContinuation = nil
            stateLock.unlock()
            continuation.finish()
            throw error
        }
    }

    func stop() {
        let continuation = stateLock.withLock { () -> AsyncStream<CapturedAudioBuffer>.Continuation? in
            let continuation = outputContinuation
            _isRunning = false
            outputContinuation = nil
            return continuation
        }

        captureEngine.stopCapturing()
        continuation?.finish()
    }
}
