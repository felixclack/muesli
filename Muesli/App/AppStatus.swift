import Foundation

enum AppStatus: String, Sendable {
    case idle
    case armed
    case recording
    case transcribing
    case needsSetup
    case failed
    case conflict

    var title: String {
        switch self {
        case .idle:
            "Idle"
        case .armed:
            "Armed"
        case .recording:
            "Recording"
        case .transcribing:
            "Transcribing"
        case .needsSetup:
            "Needs Setup"
        case .failed:
            "Failed"
        case .conflict:
            "Conflict"
        }
    }
}
