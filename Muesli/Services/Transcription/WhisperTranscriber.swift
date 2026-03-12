@preconcurrency import AVFoundation
import Foundation
import OSLog
import whisper

actor WhisperTranscriber {
    enum TranscriberError: Error {
        case missingAudio
        case initializationFailed
        case transcriptionFailed
    }

    private let fileManager: FileManager
    private let modelURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelURL = baseURL.appendingPathComponent("Muesli/Models/ggml-small.en.bin")
    }

    func modelExists() -> Bool {
        fileManager.fileExists(atPath: modelURL.path)
    }

    func ensureModel() async throws -> URL {
        guard !modelExists() else { return modelURL }

        try fileManager.createDirectory(at: modelURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let sourceURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin?download=true")!
        Logger.transcription.info("Downloading Whisper model to \(self.modelURL.path, privacy: .public)")
        let (tempURL, _) = try await URLSession.shared.download(from: sourceURL)
        _ = try? fileManager.removeItem(at: modelURL)
        try fileManager.moveItem(at: tempURL, to: modelURL)
        return modelURL
    }

    func transcribe(session: inout MeetingSession) async throws {
        let sessionTitle = session.title
        Logger.transcription.info("Starting transcription for \(sessionTitle, privacy: .public)")
        let modelURL = try await ensureModel()
        let microphoneURL = session.artifacts.microphoneAudioPath.map(URL.init(fileURLWithPath:))
        let systemURL = session.artifacts.systemAudioPath.map(URL.init(fileURLWithPath:))
        let mixedURL = session.artifacts.mixedAudioPath.map(URL.init(fileURLWithPath:))

        let diarizedSegments: [TranscriptSegment]
        let diarized: Bool

        if let microphoneURL, let systemURL {
            let microphoneSegments = try transcribeSegments(
                from: microphoneURL,
                speaker: .you,
                modelURL: modelURL,
                sessionTitle: sessionTitle
            )
            let systemSegments = try transcribeSegments(
                from: systemURL,
                speaker: .others,
                modelURL: modelURL,
                sessionTitle: sessionTitle
            )
            diarizedSegments = TranscriptComposer.diarizedSegments(
                microphoneSegments: microphoneSegments,
                systemSegments: systemSegments
            )
            diarized = true
        } else if let mixedURL {
            diarizedSegments = try transcribeSegments(
                from: mixedURL,
                speaker: nil,
                modelURL: modelURL,
                sessionTitle: sessionTitle
            )
            diarized = false
        } else {
            throw TranscriberError.missingAudio
        }

        let fullText = TranscriptComposer.renderPlainText(from: diarizedSegments)

        let folderURL = URL(fileURLWithPath: session.storageFolderPath, isDirectory: true)
        let transcriptURL = folderURL.appendingPathComponent("transcript.txt")
        let segmentsURL = folderURL.appendingPathComponent("segments.json")

        try fullText.write(to: transcriptURL, atomically: true, encoding: String.Encoding.utf8)
        let segmentsData = try JSONEncoder.pretty.encode(diarizedSegments)
        try segmentsData.write(to: segmentsURL, options: .atomic)

        session.transcript = TranscriptArtifact(
            transcriptPath: transcriptURL.path,
            segmentsPath: segmentsURL.path,
            language: "en",
            segmentCount: diarizedSegments.count,
            diarized: diarized
        )
        session.errorMessage = nil
        session.state = .completed
        Logger.transcription.info("Finished transcription for \(sessionTitle, privacy: .public) with \(diarizedSegments.count, privacy: .public) segments")
    }

    private func transcribeSegments(from url: URL, speaker: TranscriptSpeaker?, modelURL: URL, sessionTitle: String) throws -> [TranscriptSegment] {
        let samples = try audioSamples(from: url)
        Logger.transcription.info(
            "Loaded \(samples.count, privacy: .public) audio samples from \(url.lastPathComponent, privacy: .public) for \(sessionTitle, privacy: .public)"
        )

        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = true
        contextParams.flash_attn = true

        guard let context = whisper_init_from_file_with_params(modelURL.path, contextParams) else {
            throw TranscriberError.initializationFailed
        }
        defer { whisper_free(context) }

        let threadCount = Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        var languageCString = Array("en".utf8CString)
        let result = languageCString.withUnsafeMutableBufferPointer { languageBuffer -> Int32 in
            params.print_progress = false
            params.print_realtime = false
            params.print_timestamps = false
            params.print_special = false
            params.translate = false
            params.language = UnsafePointer(languageBuffer.baseAddress)
            params.n_threads = threadCount
            params.no_context = true
            params.single_segment = false
            return samples.withUnsafeBufferPointer { buffer -> Int32 in
                whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
            }
        }

        guard result == 0 else {
            Logger.transcription.error(
                "Whisper returned non-zero status \(result, privacy: .public) for \(url.lastPathComponent, privacy: .public) in \(sessionTitle, privacy: .public)"
            )
            throw TranscriberError.transcriptionFailed
        }

        let segmentCount = Int(whisper_full_n_segments(context))
        var segments: [TranscriptSegment] = []

        for index in 0..<segmentCount {
            let text = String(cString: whisper_full_get_segment_text(context, Int32(index))).trimmingCharacters(in: .whitespacesAndNewlines)
            let start = whisper_full_get_segment_t0(context, Int32(index)) * 10
            let end = whisper_full_get_segment_t1(context, Int32(index)) * 10
            segments.append(TranscriptSegment(startMS: start, endMS: end, text: text, speaker: speaker))
        }

        return segments
    }

    private func audioSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat) else {
            throw NSError(domain: "WhisperTranscriber", code: -10, userInfo: [NSLocalizedDescriptionKey: "Unable to create audio converter"])
        }

        var samples: [Float] = []
        let inputCapacity: AVAudioFrameCount = 4096

        while file.framePosition < file.length {
            let remainingFrames = AVAudioFrameCount(min(Int64(inputCapacity), file.length - file.framePosition))
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: remainingFrames)!
            try file.read(into: inputBuffer, frameCount: remainingFrames)
            if inputBuffer.frameLength == 0 { break }

            let ratio = outputFormat.sampleRate / file.processingFormat.sampleRate
            let outputCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 64)
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: max(outputCapacity, 1024))!

            var localError: NSError?
            let status = converter.convert(to: outputBuffer, error: &localError) { _, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }

            if let localError {
                throw localError
            }

            guard status == .haveData || status == .inputRanDry else { continue }
            let channelData = outputBuffer.floatChannelData![0]
            let frameCount = Int(outputBuffer.frameLength)
            samples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: frameCount))
        }

        return samples
    }
}
