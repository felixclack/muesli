import Foundation

enum MeetingArmer {
    static func armedMeetings(from candidates: [MeetingCandidate], now: Date = .now, settings: AppSettings) -> [ArmedMeeting] {
        candidates.compactMap { candidate in
            let armStart = candidate.startDate.addingTimeInterval(-settings.startLeadTime)
            let armEnd = candidate.endDate.addingTimeInterval(settings.endGraceTime)
            guard armStart <= now, now <= armEnd else { return nil }

            return ArmedMeeting(
                candidate: candidate,
                armStart: armStart,
                armEnd: armEnd,
                canonicalMeetingKey: candidate.link.canonicalURL.absoluteString
            )
        }
        .sorted { $0.candidate.startDate < $1.candidate.startDate }
    }
}
