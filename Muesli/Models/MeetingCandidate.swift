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

struct UpcomingMeetingSummary: Identifiable, Hashable, Sendable {
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let participantSummary: String?
    let platformName: String

    var id: String { eventIdentifier }

    var detailLine: String {
        guard let participantSummary, !participantSummary.isEmpty else {
            return platformName
        }

        return "\(participantSummary) • \(platformName)"
    }

    static func nextThreeToday(
        from meetings: [UpcomingMeetingSummary],
        now: Date,
        calendar: Calendar = .current
    ) -> [UpcomingMeetingSummary] {
        meetings
            .filter { meeting in
                meeting.startDate >= now && calendar.isDate(meeting.startDate, inSameDayAs: now)
            }
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)
            .map { $0 }
    }
}
