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
}
