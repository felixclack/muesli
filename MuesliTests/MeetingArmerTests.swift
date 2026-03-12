import XCTest
@testable import Muesli

final class MeetingArmerTests: XCTestCase {
    func testArmsMeetingInsideWindow() throws {
        let link = try XCTUnwrap(MeetingURLExtractor.extract(
            from: URL(string: "https://meet.google.com/abc-defg-hij")!,
            location: nil,
            notes: nil
        ))

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let candidate = MeetingCandidate(
            eventIdentifier: "event-1",
            calendarTitle: "Work",
            title: "Weekly Sync",
            startDate: now.addingTimeInterval(10 * 60),
            endDate: now.addingTimeInterval(70 * 60),
            location: nil,
            notes: nil,
            link: link
        )

        let armed = MeetingArmer.armedMeetings(from: [candidate], now: now, settings: .default)
        XCTAssertEqual(armed.count, 1)
        XCTAssertEqual(armed.first?.candidate.title, "Weekly Sync")
    }

    func testDoesNotArmMeetingOutsideGraceWindow() throws {
        let link = try XCTUnwrap(MeetingURLExtractor.extract(
            from: URL(string: "https://meet.google.com/abc-defg-hij")!,
            location: nil,
            notes: nil
        ))

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let candidate = MeetingCandidate(
            eventIdentifier: "event-2",
            calendarTitle: "Work",
            title: "Expired Sync",
            startDate: now.addingTimeInterval(-5 * 60 * 60),
            endDate: now.addingTimeInterval(-4 * 60 * 60),
            location: nil,
            notes: nil,
            link: link
        )

        let armed = MeetingArmer.armedMeetings(from: [candidate], now: now, settings: .default)
        XCTAssertTrue(armed.isEmpty)
    }

    func testUpcomingMeetingSummaryReturnsNextThreeMeetingsToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 9, minute: 0))!
        let meetings = [
            UpcomingMeetingSummary(
                eventIdentifier: "meeting-1",
                title: "Tomorrow planning",
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 9, minute: 0))!,
                participantSummary: "Alex",
                platformName: "Zoom"
            ),
            UpcomingMeetingSummary(
                eventIdentifier: "meeting-2",
                title: "Standup",
                startDate: now.addingTimeInterval(15 * 60),
                participantSummary: "Priya",
                platformName: "Google Meet"
            ),
            UpcomingMeetingSummary(
                eventIdentifier: "meeting-3",
                title: "Design review",
                startDate: now.addingTimeInterval(2 * 60 * 60),
                participantSummary: "Casey",
                platformName: "Gather"
            ),
            UpcomingMeetingSummary(
                eventIdentifier: "meeting-4",
                title: "Lunch",
                startDate: now.addingTimeInterval(-15 * 60),
                participantSummary: "Team",
                platformName: "In Person"
            ),
            UpcomingMeetingSummary(
                eventIdentifier: "meeting-5",
                title: "Retro",
                startDate: now.addingTimeInterval(4 * 60 * 60),
                participantSummary: "Jordan",
                platformName: "Zoom"
            ),
            UpcomingMeetingSummary(
                eventIdentifier: "meeting-6",
                title: "Wrap-up",
                startDate: now.addingTimeInterval(6 * 60 * 60),
                participantSummary: "Taylor",
                platformName: "Google Meet"
            )
        ]

        let upcoming = UpcomingMeetingSummary.nextThreeToday(from: meetings, now: now, calendar: calendar)

        XCTAssertEqual(upcoming.map(\.eventIdentifier), ["meeting-2", "meeting-3", "meeting-5"])
    }
}
