import AVFoundation
import CoreMedia

enum AudioFormatConversionError: Error {
    case converterCreationFailed
    case conversionFailed
}

final class AudioFormatConverter {
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat

    init(targetFormat: AVAudioFormat) {
        self.targetFormat = targetFormat
    }

    private func ensureConverter(for sourceBuffer: AVAudioPCMBuffer) throws -> AVAudioConverter {
        guard let sourceFormat = sourceBuffer.format as AVAudioFormat? else {
            throw AudioFormatConversionError.converterCreationFailed
        }

        if sourceFormat.commonFormat == targetFormat.commonFormat,
           sourceFormat.sampleRate == targetFormat.sampleRate,
           sourceFormat.channelCount == targetFormat.channelCount {
            throw AudioFormatConversionError.converterCreationFailed
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw AudioFormatConversionError.converterCreationFailed
        }
        return converter
    }

    func convertBuffer(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let sourceFormat = buffer.format as AVAudioFormat? else {
            throw AudioFormatConversionError.converterCreationFailed
        }

        if sourceFormat.commonFormat == targetFormat.commonFormat,
           sourceFormat.sampleRate == targetFormat.sampleRate,
           sourceFormat.channelCount == targetFormat.channelCount {
            return buffer
        }

        let converter = try ensureConverter(for: buffer)

        let outputFrameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * targetFormat.sampleRate / sourceFormat.sampleRate
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw AudioFormatConversionError.conversionFailed
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error || error != nil {
            throw AudioFormatConversionError.conversionFailed
        }

        return outputBuffer
    }
}
