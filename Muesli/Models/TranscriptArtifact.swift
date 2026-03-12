import Foundation

struct TranscriptSegment: Codable, Hashable, Sendable {
    let startMS: Int64
    let endMS: Int64
    let text: String
}

struct TranscriptArtifact: Codable, Hashable, Sendable {
    let transcriptPath: String
    let segmentsPath: String
    let language: String
    let segmentCount: Int
}
