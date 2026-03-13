import AVFAudio
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

    var blocksManualRecording: Bool {
        switch kind {
        case .screenRecording, .microphone:
            true
        case .calendar, .diaAutomation, .model:
            false
        }
    }
}

actor PermissionsService {
    private let calendarAuthorizationStatus: @Sendable () async -> EKAuthorizationStatus
    private let requestCalendarAccess: @Sendable () async -> Bool
    private let screenRecordingAuthorized: @Sendable () -> Bool
    private let requestScreenRecordingAccess: @Sendable () -> Bool
    private let microphonePermission: @Sendable () -> AVAudioApplication.recordPermission
    private let requestMicrophonePermission: @Sendable () async -> Bool
    private let diaProbe: @Sendable () async -> Bool
    private let modelProbe: @Sendable () async -> Bool

    init(
        calendarSource: CalendarMeetingSource,
        diaProbe: @escaping @Sendable () async -> Bool,
        modelProbe: @escaping @Sendable () async -> Bool,
        screenRecordingAuthorized: @escaping @Sendable () -> Bool = { CGPreflightScreenCaptureAccess() },
        requestScreenRecordingAccess: @escaping @Sendable () -> Bool = { CGRequestScreenCaptureAccess() },
        microphonePermission: @escaping @Sendable () -> AVAudioApplication.recordPermission = { AVAudioApplication.shared.recordPermission },
        requestMicrophonePermission: @escaping @Sendable () async -> Bool = {
            await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    ) {
        self.calendarAuthorizationStatus = { await calendarSource.authorizationStatus() }
        self.requestCalendarAccess = { await calendarSource.requestFullAccess() }
        self.screenRecordingAuthorized = screenRecordingAuthorized
        self.requestScreenRecordingAccess = requestScreenRecordingAccess
        self.microphonePermission = microphonePermission
        self.requestMicrophonePermission = requestMicrophonePermission
        self.diaProbe = diaProbe
        self.modelProbe = modelProbe
    }

    init(
        calendarAuthorizationStatus: @escaping @Sendable () async -> EKAuthorizationStatus,
        requestCalendarAccess: @escaping @Sendable () async -> Bool,
        screenRecordingAuthorized: @escaping @Sendable () -> Bool,
        requestScreenRecordingAccess: @escaping @Sendable () -> Bool,
        microphonePermission: @escaping @Sendable () -> AVAudioApplication.recordPermission,
        requestMicrophonePermission: @escaping @Sendable () async -> Bool,
        diaProbe: @escaping @Sendable () async -> Bool,
        modelProbe: @escaping @Sendable () async -> Bool
    ) {
        self.calendarAuthorizationStatus = calendarAuthorizationStatus
        self.requestCalendarAccess = requestCalendarAccess
        self.screenRecordingAuthorized = screenRecordingAuthorized
        self.requestScreenRecordingAccess = requestScreenRecordingAccess
        self.microphonePermission = microphonePermission
        self.requestMicrophonePermission = requestMicrophonePermission
        self.diaProbe = diaProbe
        self.modelProbe = modelProbe
    }

    func requestMissingPermissions() async {
        if !screenRecordingAuthorized() {
            _ = requestScreenRecordingAccess()
        }

        if microphonePermission() == .undetermined {
            _ = await requestMicrophonePermission()
        }

        if await calendarAuthorizationStatus() == .notDetermined {
            _ = await requestCalendarAccess()
        }

        _ = await diaProbe()
    }

    func currentRequirements() async -> [SetupRequirement] {
        let calendarStatus = await calendarAuthorizationStatus()
        let micStatus = microphonePermission()
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
                satisfied: screenRecordingAuthorized(),
                instructions: "Grant Screen Recording so Muesli can capture system audio via ScreenCaptureKit."
            ),
            SetupRequirement(
                kind: .microphone,
                title: "Microphone",
                satisfied: micStatus == .granted,
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
