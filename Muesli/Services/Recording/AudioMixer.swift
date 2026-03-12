import AVFoundation
import Foundation

enum AudioMixer {
    static func mix(systemAudioURL: URL, microphoneAudioURL: URL, outputURL: URL) async throws {
        let composition = AVMutableComposition()
        let systemAsset = AVURLAsset(url: systemAudioURL)
        let micAsset = AVURLAsset(url: microphoneAudioURL)

        guard let systemTrack = try await systemAsset.loadTracks(withMediaType: .audio).first,
              let micTrack = try await micAsset.loadTracks(withMediaType: .audio).first,
              let compositionSystemTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compositionMicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw NSError(domain: "AudioMixer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to load audio tracks"])
        }

        let systemTimeRange = try await systemTrack.load(.timeRange)
        let micTimeRange = try await micTrack.load(.timeRange)
        try compositionSystemTrack.insertTimeRange(systemTimeRange, of: systemTrack, at: .zero)
        try compositionMicTrack.insertTimeRange(micTimeRange, of: micTrack, at: .zero)

        let systemMix = AVMutableAudioMixInputParameters(track: compositionSystemTrack)
        systemMix.setVolume(1, at: .zero)
        let micMix = AVMutableAudioMixInputParameters(track: compositionMicTrack)
        micMix.setVolume(1, at: .zero)

        let mix = AVMutableAudioMix()
        mix.inputParameters = [systemMix, micMix]

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "AudioMixer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session"])
        }

        exportSession.audioMix = mix
        try await exportSession.export(to: outputURL, as: .m4a)
    }
}
