@preconcurrency import AVFoundation
@preconcurrency import CoreMedia
import Foundation
import OSLog

final class AudioSampleWriter: @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "com.felixclack.Muesli.AudioSampleWriter")
    private var assetWriter: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var startTime: CMTime?

    init(url: URL) {
        self.url = url
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        queue.async {
            do {
                try self.startIfNeeded(with: sampleBuffer)
                guard let input = self.input, input.isReadyForMoreMediaData else { return }
                _ = input.append(sampleBuffer)
            } catch {
                Logger.recorder.error("Failed to append sample buffer: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func finish() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard let assetWriter = self.assetWriter, let input = self.input else {
                    continuation.resume(returning: ())
                    return
                }

                input.markAsFinished()
                assetWriter.finishWriting {
                    if assetWriter.status == .failed {
                        continuation.resume(throwing: assetWriter.error ?? NSError(domain: "AudioSampleWriter", code: -1))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }

    private func startIfNeeded(with sampleBuffer: CMSampleBuffer) throws {
        guard assetWriter == nil else { return }

        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000
        ]

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings, sourceFormatHint: CMSampleBufferGetFormatDescription(sampleBuffer))
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw NSError(domain: "AudioSampleWriter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot add audio input"])
        }

        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "AudioSampleWriter", code: -3)
        }

        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        writer.startSession(atSourceTime: presentationTimeStamp)

        self.assetWriter = writer
        self.input = input
        self.startTime = presentationTimeStamp
    }
}
