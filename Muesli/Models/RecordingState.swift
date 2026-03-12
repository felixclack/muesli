import Foundation

enum RecordingState: String, Codable, CaseIterable, Sendable {
    case idle
    case armed
    case recording
    case mixing
    case transcribing
    case completed
    case failed
    case needsPermissions
    case interrupted
}
