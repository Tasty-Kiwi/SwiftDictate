import AVFoundation
import Foundation

enum AudioCaptureError: Error {
    case engineNotRunning
    case audioUnitNotFound
    case noInputNode
    case tapInstallationFailed
}

final class AudioCaptureService: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var outputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private let stateLock = NSLock()

    var format: AVAudioFormat? { engine.inputNode.outputFormat(forBus: 0) }

    private var _isRunning = false
    var isRunning: Bool {
        stateLock.withLock { _isRunning }
    }

    deinit {
        stop()
    }

    func start() throws -> AsyncStream<AVAudioPCMBuffer> {
        stateLock.lock()
        guard !_isRunning else {
            stateLock.unlock()
            throw AudioCaptureError.engineNotRunning
        }
        stateLock.unlock()

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        return AsyncStream<AVAudioPCMBuffer> { continuation in
            self.outputContinuation = continuation

            inputNode.installTap(
                onBus: 0,
                bufferSize: 4096,
                format: recordingFormat
            ) { buffer, _ in
                continuation.yield(buffer)
            }

            do {
                engine.prepare()
                try engine.start()
                self.stateLock.withLock { self._isRunning = true }
            } catch {
                continuation.finish()
            }
        }
    }

    func stop() {
        stateLock.lock()
        guard _isRunning else {
            stateLock.unlock()
            return
        }
        _isRunning = false
        stateLock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        outputContinuation?.finish()
        outputContinuation = nil
    }
}
