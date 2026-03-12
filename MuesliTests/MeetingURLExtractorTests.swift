import XCTest
@testable import Muesli

final class MeetingURLExtractorTests: XCTestCase {
    func testExtractsGoogleMeetFromNotes() {
        let link = MeetingURLExtractor.extract(
            from: nil,
            location: nil,
            notes: "Join here: https://meet.google.com/abc-defg-hij?pli=1"
        )

        XCTAssertEqual(link?.provider, .googleMeet)
        XCTAssertEqual(link?.canonicalURL.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testExtractsGatherFromLocation() {
        let link = MeetingURLExtractor.extract(
            from: nil,
            location: "https://app.gather.town/app/team-space/room-one?foo=bar",
            notes: nil
        )

        XCTAssertEqual(link?.provider, .gather)
        XCTAssertEqual(link?.canonicalURL.absoluteString, "https://app.gather.town/app/team-space/room-one")
    }

    func testIgnoresUnsupportedLinks() {
        let link = MeetingURLExtractor.extract(
            from: URL(string: "https://example.com")!,
            location: nil,
            notes: nil
        )

        XCTAssertNil(link)
    }
}
