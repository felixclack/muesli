import AVFoundation
import CoreGraphics
import EventKit
import Foundation

struct SetupRequirement: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case calendar
        case screenRecording
        case microphone
        case diaAutomation
        case model
    }

    let kind: Kind
    let title: String
    let satisfied: Bool
    let instructions: String

    var id: String { kind.rawValue }
}

actor PermissionsService {
    private let calendarSource: CalendarMeetingSource
    private let diaProbe: @Sendable () async -> Bool
    private let modelProbe: @Sendable () async -> Bool

    init(calendarSource: CalendarMeetingSource, diaProbe: @escaping @Sendable () async -> Bool, modelProbe: @escaping @Sendable () async -> Bool) {
        self.calendarSource = calendarSource
        self.diaProbe = diaProbe
        self.modelProbe = modelProbe
    }

    func requestMissingPermissions() async {
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }

        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        if await calendarSource.authorizationStatus() == .notDetermined {
            _ = await calendarSource.requestFullAccess()
        }

        _ = await diaProbe()
    }

    func currentRequirements() async -> [SetupRequirement] {
        let calendarStatus = await calendarSource.authorizationStatus()
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let diaAuthorized = await diaProbe()

        return [
            SetupRequirement(
                kind: .calendar,
                title: "Calendar",
                satisfied: calendarStatus == .fullAccess,
                instructions: "Grant Calendar Full Access so Muesli can arm upcoming meetings."
            ),
            SetupRequirement(
                kind: .screenRecording,
                title: "Screen Recording",
                satisfied: CGPreflightScreenCaptureAccess(),
                instructions: "Grant Screen Recording so Muesli can capture system audio via ScreenCaptureKit."
            ),
            SetupRequirement(
                kind: .microphone,
                title: "Microphone",
                satisfied: micStatus == .authorized,
                instructions: "Grant Microphone access so Muesli can capture your voice."
            ),
            SetupRequirement(
                kind: .diaAutomation,
                title: "Dia Automation",
                satisfied: diaAuthorized,
                instructions: "Allow Muesli to control Dia so it can detect Google Meet joins."
            ),
            SetupRequirement(
                kind: .model,
                title: "Whisper Model",
                satisfied: await modelProbe(),
                instructions: "Download the English Whisper model so local transcription can run."
            )
        ]
    }
}
