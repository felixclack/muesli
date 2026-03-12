import Foundation

struct RecordingArtifacts: Codable, Hashable, Sendable {
    var systemAudioPath: String?
    var microphoneAudioPath: String?
    var mixedAudioPath: String?
}

struct MeetingSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let meetingIdentifier: String
    let provider: MeetingProviderKind
    let title: String
    let scheduledStart: Date
    let scheduledEnd: Date
    let canonicalMeetingURL: String?
    let storageFolderPath: String
    var startedAt: Date?
    var endedAt: Date?
    var state: RecordingState
    var artifacts: RecordingArtifacts
    var transcript: TranscriptArtifact?
    var errorMessage: String?
    var interrupted: Bool

    init(meetingIdentifier: String, provider: MeetingProviderKind, title: String, scheduledStart: Date, scheduledEnd: Date, canonicalMeetingURL: String?, storageFolderPath: String) {
        self.id = UUID()
        self.meetingIdentifier = meetingIdentifier
        self.provider = provider
        self.title = title
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.canonicalMeetingURL = canonicalMeetingURL
        self.storageFolderPath = storageFolderPath
        self.startedAt = nil
        self.endedAt = nil
        self.state = .idle
        self.artifacts = RecordingArtifacts(systemAudioPath: nil, microphoneAudioPath: nil, mixedAudioPath: nil)
        self.transcript = nil
        self.errorMessage = nil
        self.interrupted = false
    }
}
