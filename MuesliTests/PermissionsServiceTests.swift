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
}

private actor PermissionRequestRecorder {
    private(set) var microphoneRequested = false

    func markMicrophoneRequested() {
        microphoneRequested = true
    }
}
