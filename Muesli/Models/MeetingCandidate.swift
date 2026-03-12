import Foundation

struct MeetingCandidate: Identifiable, Codable, Hashable, Sendable {
    let eventIdentifier: String
    let calendarTitle: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let link: MeetingLink

    var id: String { eventIdentifier }
}
