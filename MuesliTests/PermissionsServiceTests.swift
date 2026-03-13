import AVFAudio
import EventKit
import XCTest
@testable import Muesli

final class PermissionsServiceTests: XCTestCase {
    func testCurrentRequirementsTreatsGrantedMicrophonePermissionAsSatisfied() async {
        let service = PermissionsService(
            calendarAuthorizationStatus: { .fullAccess },
            requestCalendarAccess: { true },
            screenRecordingAuthorized: { true },
            requestScreenRecordingAccess: { true },
            microphonePermission: { .granted },
            requestMicrophonePermission: { true },
            diaProbe: { true },
            modelProbe: { true }
        )

        let requirements = await service.currentRequirements()

        XCTAssertEqual(requirements.first(where: { $0.kind == .microphone })?.satisfied, true)
    }

    func testRequestMissingPermissionsRequestsUndeterminedMicrophoneAccess() async {
        let recorder = PermissionRequestRecorder()
        let service = PermissionsService(
            calendarAuthorizationStatus: { .fullAccess },
            requestCalendarAccess: { true },
            screenRecordingAuthorized: { true },
            requestScreenRecordingAccess: { true },
            microphonePermission: { .undetermined },
            requestMicrophonePermission: {
                await recorder.markMicrophoneRequested()
                return true
            },
            diaProbe: { true },
            modelProbe: { true }
        )

        await service.requestMissingPermissions()

        let microphoneRequested = await recorder.microphoneRequested
        XCTAssertTrue(microphoneRequested)
    }

    func testCurrentRequirementsTreatGrantedPromptAsSatisfiedUntilSystemStateCatchesUp() async {
        let service = PermissionsService(
            calendarAuthorizationStatus: { .fullAccess },
            requestCalendarAccess: { true },
            screenRecordingAuthorized: { true },
            requestScreenRecordingAccess: { true },
            microphonePermission: { .undetermined },
            requestMicrophonePermission: { true },
            diaProbe: { true },
            modelProbe: { true }
        )

        await service.requestMissingPermissions()
        let requirements = await service.currentRequirements()

        XCTAssertEqual(requirements.first(where: { $0.kind == .microphone })?.satisfied, true)
    }

    func testCurrentRequirementsMarksDeniedMicrophoneAsOpenSettingsStep() async {
        let service = PermissionsService(
            calendarAuthorizationStatus: { .fullAccess },
            requestCalendarAccess: { true },
            screenRecordingAuthorized: { true },
            requestScreenRecordingAccess: { true },
            microphonePermission: { .denied },
            requestMicrophonePermission: { true },
            diaProbe: { true },
            modelProbe: { true }
        )

        let requirements = await service.currentRequirements()

        XCTAssertEqual(requirements.first(where: { $0.kind == .microphone })?.resolution, .openSystemSettings)
    }

    func testCurrentRequirementsMarksUndeterminedCalendarAsRequestAccessStep() async {
        let service = PermissionsService(
            calendarAuthorizationStatus: { .notDetermined },
            requestCalendarAccess: { true },
            screenRecordingAuthorized: { true },
            requestScreenRecordingAccess: { true },
            microphonePermission: { .granted },
            requestMicrophonePermission: { true },
            diaProbe: { true },
            modelProbe: { true }
        )

        let requirements = await service.currentRequirements()

        XCTAssertEqual(requirements.first(where: { $0.kind == .calendar })?.resolution, .requestAccess)
    }

    func testInitialPermissionPromptGatePromptsForRequestAccessRequirementsOnce() {
        let (gate, defaults, suiteName) = makeInitialPermissionPromptGate()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let requirements = [
            SetupRequirement(
                kind: .microphone,
                title: "Microphone",
                satisfied: false,
                instructions: "Grant Microphone access so Muesli can capture your voice.",
                resolution: .requestAccess
            )
        ]

        XCTAssertTrue(gate.shouldPrompt(for: requirements))

        gate.markPrompted()

        XCTAssertFalse(gate.shouldPrompt(for: requirements))
    }

    func testInitialPermissionPromptGateSkipsDeniedRequirements() {
        let (gate, defaults, suiteName) = makeInitialPermissionPromptGate()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let deniedRequirements = [
            SetupRequirement(
                kind: .calendar,
                title: "Calendar",
                satisfied: false,
                instructions: "Grant Calendar Full Access so Muesli can arm upcoming meetings.",
                resolution: .openSystemSettings
            )
        ]

        XCTAssertFalse(gate.shouldPrompt(for: deniedRequirements))
    }

    private func makeInitialPermissionPromptGate() -> (InitialPermissionPromptGate, UserDefaults, String) {
        let suiteName = "PermissionsServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (InitialPermissionPromptGate(defaults: defaults), defaults, suiteName)
    }
}

private actor PermissionRequestRecorder {
    private(set) var microphoneRequested = false

    func markMicrophoneRequested() {
        microphoneRequested = true
    }
}
