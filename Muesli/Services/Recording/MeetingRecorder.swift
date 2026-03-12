import AVFoundation
import Foundation
import OSLog
@preconcurrency import ScreenCaptureKit

final class MeetingRecorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    enum RecorderError: Error {
        case missingDisplay
        case alreadyRecording
        case notRecording
    }

    private var stream: SCStream?
    private var systemWriter: AudioSampleWriter?
    private var microphoneWriter: AudioSampleWriter?
    private let sampleQueue = DispatchQueue(label: "com.felixclack.Muesli.StreamSamples")

    private(set) var lastSystemAudioActivity: Date?

    func start(session: inout MeetingSession) async throws {
        guard stream == nil else { throw RecorderError.alreadyRecording }

        let shareableContent = try await SCShareableContent.getShareableContent()
        guard let display = shareableContent.displays.first else {
            throw RecorderError.missingDisplay
        }

        let contentFilter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.captureMicrophone = true
        configuration.excludesCurrentProcessAudio = true
        configuration.minimumFrameInterval = .zero
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.queueDepth = 3

        let folderURL = URL(fileURLWithPath: session.storageFolderPath, isDirectory: true)
        let systemURL = folderURL.appendingPathComponent("system.m4a")
        let micURL = folderURL.appendingPathComponent("mic.m4a")

        systemWriter = AudioSampleWriter(url: systemURL)
        microphoneWriter = AudioSampleWriter(url: micURL)

        let stream = SCStream(filter: contentFilter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()

        self.stream = stream
        session.startedAt = .now
        session.state = .recording
        session.artifacts.systemAudioPath = systemURL.path
        session.artifacts.microphoneAudioPath = micURL.path
        lastSystemAudioActivity = .now

    }

    func stop(session: inout MeetingSession) async throws {
        guard let stream else { throw RecorderError.notRecording }

        try await stream.stopCapture()
        try await systemWriter?.finish()
        try await microphoneWriter?.finish()

        let mixedURL = URL(fileURLWithPath: session.storageFolderPath, isDirectory: true).appendingPathComponent("mix.m4a")
        if let systemPath = session.artifacts.systemAudioPath,
           let microphonePath = session.artifacts.microphoneAudioPath {
            try await AudioMixer.mix(
                systemAudioURL: URL(fileURLWithPath: systemPath),
                microphoneAudioURL: URL(fileURLWithPath: microphonePath),
                outputURL: mixedURL
            )
            session.artifacts.mixedAudioPath = mixedURL.path
        }

        session.endedAt = .now
        session.state = .mixing

        self.stream = nil
        systemWriter = nil
        microphoneWriter = nil

    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard CMSampleBufferIsValid(sampleBuffer) else { return }

        switch outputType {
        case .audio:
            lastSystemAudioActivity = .now
            systemWriter?.append(sampleBuffer)
        case .microphone:
            microphoneWriter?.append(sampleBuffer)
        default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Logger.recorder.error("Stream stopped with error: \(error.localizedDescription, privacy: .public)")
    }
}

private extension SCShareableContent {
    static func getShareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SCShareableContent, Error>) in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "SCShareableContent", code: -1))
                }
            }
        }
    }
}

private extension SCStream {
    func startCapture() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func stopCapture() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stopCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
