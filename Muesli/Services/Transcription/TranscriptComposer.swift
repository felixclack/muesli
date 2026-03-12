import Foundation

enum TranscriptComposer {
    static let mergeGapMS: Int64 = 750

    static func diarizedSegments(microphoneSegments: [TranscriptSegment], systemSegments: [TranscriptSegment]) -> [TranscriptSegment] {
        let combined = (microphoneSegments + systemSegments).sorted(by: compareSegments)
        return mergeAdjacentSegments(in: combined, gapMS: mergeGapMS)
    }

    static func renderPlainText(from segments: [TranscriptSegment]) -> String {
        let lines = segments.compactMap { segment -> String? in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            if let speaker = segment.speaker {
                return "\(speaker.displayName): \(text)"
            }

            return text
        }

        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func compareSegments(lhs: TranscriptSegment, rhs: TranscriptSegment) -> Bool {
        if lhs.startMS != rhs.startMS {
            return lhs.startMS < rhs.startMS
        }

        if lhs.endMS != rhs.endMS {
            return lhs.endMS < rhs.endMS
        }

        let lhsSpeaker = lhs.speaker?.rawValue ?? ""
        let rhsSpeaker = rhs.speaker?.rawValue ?? ""
        return lhsSpeaker < rhsSpeaker
    }

    private static func mergeAdjacentSegments(in segments: [TranscriptSegment], gapMS: Int64) -> [TranscriptSegment] {
        var merged: [TranscriptSegment] = []

        for segment in segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let normalized = TranscriptSegment(
                startMS: segment.startMS,
                endMS: segment.endMS,
                text: text,
                speaker: segment.speaker
            )

            guard let last = merged.last else {
                merged.append(normalized)
                continue
            }

            let shouldMerge = last.speaker == normalized.speaker && normalized.startMS <= last.endMS + gapMS
            guard shouldMerge else {
                merged.append(normalized)
                continue
            }

            let joinedText = joinText(last.text, normalized.text)
            merged[merged.count - 1] = TranscriptSegment(
                startMS: last.startMS,
                endMS: max(last.endMS, normalized.endMS),
                text: joinedText,
                speaker: last.speaker
            )
        }

        return merged
    }

    private static func joinText(_ lhs: String, _ rhs: String) -> String {
        guard !lhs.isEmpty else { return rhs }
        guard !rhs.isEmpty else { return lhs }
        return "\(lhs) \(rhs)"
    }
}
