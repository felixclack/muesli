import XCTest
@testable import Muesli

final class TranscriptComposerTests: XCTestCase {
    func testMergesAndSortsMicrophoneAndSystemSegments() {
        let microphoneSegments = [
            TranscriptSegment(startMS: 0, endMS: 600, text: "Hey team", speaker: .you),
            TranscriptSegment(startMS: 1_500, endMS: 2_000, text: "I can take that", speaker: .you)
        ]
        let systemSegments = [
            TranscriptSegment(startMS: 800, endMS: 1_200, text: "Thanks", speaker: .others),
            TranscriptSegment(startMS: 2_200, endMS: 2_600, text: "Sounds good", speaker: .others)
        ]

        let segments = TranscriptComposer.diarizedSegments(
            microphoneSegments: microphoneSegments,
            systemSegments: systemSegments
        )

        XCTAssertEqual(segments.map(\.speaker), [.you, .others, .you, .others])
        XCTAssertEqual(segments.map(\.text), ["Hey team", "Thanks", "I can take that", "Sounds good"])
    }

    func testMergesNearbySegmentsFromSameSpeaker() {
        let microphoneSegments = [
            TranscriptSegment(startMS: 0, endMS: 400, text: "Let me", speaker: .you),
            TranscriptSegment(startMS: 700, endMS: 1_000, text: "share that", speaker: .you)
        ]

        let segments = TranscriptComposer.diarizedSegments(
            microphoneSegments: microphoneSegments,
            systemSegments: []
        )

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.speaker, .you)
        XCTAssertEqual(segments.first?.text, "Let me share that")
        XCTAssertEqual(segments.first?.endMS, 1_000)
    }

    func testRenderPlainTextIncludesSpeakerLabelsWhenPresent() {
        let segments = [
            TranscriptSegment(startMS: 0, endMS: 500, text: "Can you hear me?", speaker: .you),
            TranscriptSegment(startMS: 800, endMS: 1_200, text: "Yes", speaker: .others),
            TranscriptSegment(startMS: 1_300, endMS: 1_700, text: "Great", speaker: nil)
        ]

        let text = TranscriptComposer.renderPlainText(from: segments)

        XCTAssertEqual(text, "You: Can you hear me?\nOthers: Yes\nGreat\n")
    }
}
