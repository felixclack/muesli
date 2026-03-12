import Foundation

enum MeetingProviderKind: String, Codable, CaseIterable, Sendable {
    case googleMeet
    case gather
    case manual

    var displayName: String {
        switch self {
        case .googleMeet:
            "Google Meet"
        case .gather:
            "Gather"
        case .manual:
            "Manual"
        }
    }
}
