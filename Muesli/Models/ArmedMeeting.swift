import Foundation

struct ArmedMeeting: Identifiable, Codable, Hashable, Sendable {
    let candidate: MeetingCandidate
    let armStart: Date
    let armEnd: Date
    let canonicalMeetingKey: String

    var id: String { candidate.id }

    func isActive(at date: Date = .now) -> Bool {
        armStart <= date && date <= armEnd
    }
}
