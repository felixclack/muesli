import Foundation

enum TranscriptSpeaker: String, Codable, Hashable, Sendable {
    case you
    case others

    var displayName: String {
        switch self {
        case .you:
            "You"
        case .others:
            "Others"
        }
    }
}

struct TranscriptSegment: Codable, Hashable, Sendable {
    let startMS: Int64
    let endMS: Int64
    let text: String
    let speaker: TranscriptSpeaker?
}

struct TranscriptArtifact: Codable, Hashable, Sendable {
    let transcriptPath: String
    let segmentsPath: String
    let language: String
    let segmentCount: Int
    let diarized: Bool?
}
