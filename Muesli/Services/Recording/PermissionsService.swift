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

    enum Resolution: String, Sendable {
        case requestAccess
        case openSystemSettings
        case downloadModel
        case retry
    }

    let kind: Kind
    let title: String
    let satisfied: Bool
    let instructions: String
    let resolution: Resolution?

    var id: String { kind.rawValue }

    var actionTitle: String? {
        switch resolution {
        case .requestAccess:
            "Grant Access"
        case .openSystemSettings:
            "Open Settings"
        case .downloadModel:
            "Download"
        case .retry:
            "Retry"
        case nil:
            nil
        }
    }

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
    private let microphonePermission: @Sendable () async -> AVAudioApplication.recordPermission
    private let requestMicrophonePermission: @Sendable () async -> Bool
    private let diaProbe: @Sendable () async -> Bool
    private let modelProbe: @Sendable () async -> Bool
    private var grantedMicrophonePermissionInProcess = false

    init(
        calendarSource: CalendarMeetingSource,
        diaProbe: @escaping @Sendable () async -> Bool,
        modelProbe: @escaping @Sendable () async -> Bool,
        screenRecordingAuthorized: @escaping @Sendable () -> Bool = { CGPreflightScreenCaptureAccess() },
        requestScreenRecordingAccess: @escaping @Sendable () -> Bool = { CGRequestScreenCaptureAccess() },
        microphonePermission: @escaping @Sendable () async -> AVAudioApplication.recordPermission = {
            await MainActor.run { AVAudioApplication.shared.recordPermission }
        },
        requestMicrophonePermission: @escaping @Sendable () async -> Bool = {
            await withCheckedContinuation { continuation in
                let completion = { (granted: Bool) in
                    continuation.resume(returning: granted)
                }

                Task { @MainActor in
                    AVAudioApplication.requestRecordPermission(completionHandler: completion)
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
        microphonePermission: @escaping @Sendable () async -> AVAudioApplication.recordPermission,
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
        _ = await resolve(.screenRecording)
        _ = await resolve(.microphone)
        _ = await resolve(.calendar)
        _ = await resolve(.diaAutomation)
    }

    func currentRequirements() async -> [SetupRequirement] {
        let calendarStatus = await calendarAuthorizationStatus()
        let micStatus = await resolvedMicrophonePermission()
        let diaAuthorized = await diaProbe()
        let modelReady = await modelProbe()

        return [
            SetupRequirement(
                kind: .calendar,
                title: "Calendar",
                satisfied: calendarStatus == .fullAccess,
                instructions: "Grant Calendar Full Access so Muesli can arm upcoming meetings.",
                resolution: calendarStatus == .fullAccess ? nil : calendarResolution(for: calendarStatus)
            ),
            SetupRequirement(
                kind: .screenRecording,
                title: "Screen Recording",
                satisfied: screenRecordingAuthorized(),
                instructions: "Grant Screen Recording so Muesli can capture system audio via ScreenCaptureKit.",
                resolution: screenRecordingAuthorized() ? nil : .requestAccess
            ),
            SetupRequirement(
                kind: .microphone,
                title: "Microphone",
                satisfied: micStatus == .granted,
                instructions: "Grant Microphone access so Muesli can capture your voice.",
                resolution: microphoneResolution(for: micStatus)
            ),
            SetupRequirement(
                kind: .diaAutomation,
                title: "Dia Automation",
                satisfied: diaAuthorized,
                instructions: "Allow Muesli to control Dia so it can detect Google Meet joins.",
                resolution: diaAuthorized ? nil : .retry
            ),
            SetupRequirement(
                kind: .model,
                title: "Whisper Model",
                satisfied: modelReady,
                instructions: "Download the English Whisper model so local transcription can run.",
                resolution: modelReady ? nil : .downloadModel
            )
        ]
    }

    func resolve(_ kind: SetupRequirement.Kind) async -> Bool {
        switch kind {
        case .calendar:
            let status = await calendarAuthorizationStatus()
            guard status != .fullAccess else { return true }
            guard status == .notDetermined else { return false }
            return await requestCalendarAccess()
        case .screenRecording:
            if screenRecordingAuthorized() {
                return true
            }

            let granted = requestScreenRecordingAccess()
            return granted || screenRecordingAuthorized()
        case .microphone:
            let status = await resolvedMicrophonePermission()
            guard status != .granted else { return true }
            guard status == .undetermined else { return false }

            grantedMicrophonePermissionInProcess = await requestMicrophonePermission()
            return await resolvedMicrophonePermission() == .granted
        case .diaAutomation:
            return await diaProbe()
        case .model:
            return await modelProbe()
        }
    }

    private func resolvedMicrophonePermission() async -> AVAudioApplication.recordPermission {
        let livePermission = await microphonePermission()

        switch livePermission {
        case .granted:
            grantedMicrophonePermissionInProcess = true
            return .granted
        case .denied:
            grantedMicrophonePermissionInProcess = false
            return .denied
        case .undetermined:
            return grantedMicrophonePermissionInProcess ? .granted : .undetermined
        @unknown default:
            return livePermission
        }
    }

    private func calendarResolution(for status: EKAuthorizationStatus) -> SetupRequirement.Resolution {
        switch status {
        case .notDetermined:
            .requestAccess
        case .fullAccess:
            .requestAccess
        default:
            .openSystemSettings
        }
    }

    private func microphoneResolution(for status: AVAudioApplication.recordPermission) -> SetupRequirement.Resolution? {
        switch status {
        case .granted:
            nil
        case .undetermined:
            .requestAccess
        case .denied:
            .openSystemSettings
        @unknown default:
            .openSystemSettings
        }
    }
}
