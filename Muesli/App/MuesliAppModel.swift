import AppKit
import Foundation
import OSLog
import ServiceManagement

@MainActor
final class MuesliAppModel: ObservableObject {
    @Published private(set) var status: AppStatus = .idle
    @Published private(set) var requirements: [SetupRequirement] = []
    @Published private(set) var armedMeetings: [ArmedMeeting] = []
    @Published private(set) var sessions: [MeetingSession] = []
    @Published private(set) var activeSession: MeetingSession?
    @Published var lastError: String?

    let settingsStore: SettingsStore

    private let repository: SessionRepository
    private let calendarSource: CalendarMeetingSource
    private let diaController: DiaController
    private let diaAdapter: DiaMeetAdapter
    private let gatherAdapter: GatherAdapter
    private let recorder: MeetingRecorder
    private let transcriber: WhisperTranscriber
    private let permissionsService: PermissionsService
    private let notifications = NotificationService()

    private var automationTask: Task<Void, Never>?
    private var negativePollDuration: TimeInterval = 0
    private var attemptedInitialPermissionBootstrap = false
    private var lastMissingRequirementSignature = ""
    private var lastArmedMeetingSignature = ""

    init() {
        let repository = SessionRepository()
        let calendarSource = CalendarMeetingSource()
        let diaController = DiaController()
        let transcriber = WhisperTranscriber()

        self.settingsStore = SettingsStore()
        self.repository = repository
        self.calendarSource = calendarSource
        self.diaController = diaController
        self.diaAdapter = DiaMeetAdapter(controller: diaController)
        self.gatherAdapter = GatherAdapter()
        self.recorder = MeetingRecorder()
        self.transcriber = transcriber
        self.permissionsService = PermissionsService(
            calendarSource: calendarSource,
            diaProbe: { await diaController.automationPermissionGranted() },
            modelProbe: { await transcriber.modelExists() }
        )

        Task {
            await loadSessions()
            await refreshRequirements()
            await bootstrapPermissionsIfNeeded()
        }
    }

    deinit {
        automationTask?.cancel()
    }

    func start() {
        guard automationTask == nil else { return }

        automationTask = Task {
            await notifications.prepare()
            await synchronizeLaunchAtLogin()

            while !Task.isCancelled {
                await tick()
                let sleepDuration = UInt64(settingsStore.settings.pollingInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepDuration)
            }
        }
    }

    func refreshNow() {
        Task { await tick() }
    }

    func requestPermissionsAndModel() {
        Task {
            await permissionsService.requestMissingPermissions()
            do {
                _ = try await transcriber.ensureModel()
            } catch {
                setError("Model download failed: \(error.localizedDescription)")
            }
            await tick()
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        settingsStore.settings.launchAtLoginEnabled = enabled

        Task {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                setError("Launch at login update failed: \(error.localizedDescription)")
            }
        }
    }

    func manualStart() {
        Task {
            if let meeting = armedMeetings.first {
                await beginSession(for: meeting)
                return
            }

            do {
                let folderURL = try await repository.createStorageFolder(for: "Manual Recording", startDate: .now)
                var session = MeetingSession(
                    meetingIdentifier: UUID().uuidString,
                    provider: .manual,
                    title: "Manual Recording",
                    scheduledStart: .now,
                    scheduledEnd: .now.addingTimeInterval(60 * 60),
                    canonicalMeetingURL: nil,
                    storageFolderPath: folderURL.path
                )
                try await repository.persist(session)
                try await recorder.start(session: &session)
                try await repository.persist(session)
                await MainActor.run {
                    activeSession = session
                    status = .recording
                    sessions.insert(session, at: 0)
                }
            } catch {
                setError("Manual recording failed: \(error.localizedDescription)")
            }
        }
    }

    func stopRecording() {
        Task {
            await finishActiveSession(markInterrupted: false)
        }
    }

    func openLatestTranscript() {
        guard let transcriptPath = sessions.first(where: { $0.transcript != nil })?.transcript?.transcriptPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: transcriptPath))
    }

    func openLatestFolder() {
        guard let path = sessions.first?.storageFolderPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func openSessionTranscript(_ session: MeetingSession) {
        guard let path = session.transcript?.transcriptPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func openSessionFolder(_ session: MeetingSession) {
        NSWorkspace.shared.open(URL(fileURLWithPath: session.storageFolderPath))
    }

    func retryTranscription(for session: MeetingSession) {
        Task {
            await retranscribe(session)
        }
    }

    private func tick() async {
        await refreshRequirements()

        let requirementsReady = requirements.allSatisfy(\.satisfied)
        let calendarReady = requirements.first(where: { $0.kind == .calendar })?.satisfied == true
        let currentSettings = settingsStore.settings

        let candidates = calendarReady ? await calendarSource.fetchCandidates(referenceDate: .now) : []
        armedMeetings = MeetingArmer.armedMeetings(from: candidates, now: .now, settings: currentSettings)
        logArmedMeetingsIfNeeded()

        if let activeSession {
            if activeSession.provider == .manual {
                status = .recording
                return
            }

            let context = ProviderPollContext(
                settings: currentSettings,
                now: .now,
                lastSystemAudioActivity: recorder.lastSystemAudioActivity
            )

            let providerState = await pollProvider(for: activeSession, context: context)
            if providerState == .joined {
                negativePollDuration = 0
                status = .recording
                return
            }

            negativePollDuration += currentSettings.pollingInterval
            let stopThreshold: TimeInterval = activeSession.provider == .googleMeet ? 90 : 180

            if negativePollDuration >= stopThreshold {
                await finishActiveSession(markInterrupted: false)
            } else {
                status = .recording
            }
            return
        }

        negativePollDuration = 0

        guard requirementsReady else {
            status = .needsSetup
            return
        }

        var joinedMeetings: [ArmedMeeting] = []
        let context = ProviderPollContext(
            settings: currentSettings,
            now: .now,
            lastSystemAudioActivity: nil
        )

        for meeting in armedMeetings {
            let state = await pollProvider(for: meeting, context: context)
            if state == .joined {
                joinedMeetings.append(meeting)
            }
        }

        if joinedMeetings.count > 1 {
            status = .conflict
            return
        }

        if let meeting = joinedMeetings.first {
            await beginSession(for: meeting)
            return
        }

        status = armedMeetings.isEmpty ? .idle : .armed
    }

    private func refreshRequirements() async {
        requirements = await permissionsService.currentRequirements()
        logRequirementsIfNeeded()
    }

    private func loadSessions() async {
        do {
            sessions = try await repository.loadSessions()
        } catch {
            setError("Failed to load existing sessions: \(error.localizedDescription)")
        }
    }

    private func synchronizeLaunchAtLogin() async {
        let registered = SMAppService.mainApp.status == .enabled
        if settingsStore.settings.launchAtLoginEnabled != registered {
            settingsStore.settings.launchAtLoginEnabled = registered
        }
    }

    private func bootstrapPermissionsIfNeeded() async {
        guard !attemptedInitialPermissionBootstrap else { return }
        attemptedInitialPermissionBootstrap = true

        let missingPermissions = requirements
            .filter { !$0.satisfied && $0.kind != .model }
            .map(\.title)

        guard !missingPermissions.isEmpty else { return }

        let missingPermissionsSummary = missingPermissions.joined(separator: ", ")
        Logger.permissions.info("Bootstrapping permissions for: \(missingPermissionsSummary, privacy: .public)")
        await permissionsService.requestMissingPermissions()
        await refreshRequirements()
    }

    private func beginSession(for meeting: ArmedMeeting) async {
        do {
            Logger.app.info("Starting session for \(meeting.candidate.title, privacy: .public)")
            let folderURL = try await repository.createStorageFolder(for: meeting.candidate.title, startDate: .now)
            var session = MeetingSession(
                meetingIdentifier: meeting.candidate.id,
                provider: meeting.candidate.link.provider,
                title: meeting.candidate.title,
                scheduledStart: meeting.candidate.startDate,
                scheduledEnd: meeting.candidate.endDate,
                canonicalMeetingURL: meeting.candidate.link.canonicalURL.absoluteString,
                storageFolderPath: folderURL.path
            )

            session.state = .armed
            try await repository.persist(session)
            try await recorder.start(session: &session)
            try await repository.persist(session)

            activeSession = session
            sessions.removeAll { $0.id == session.id }
            sessions.insert(session, at: 0)
            status = .recording

            await notifications.send(title: "Muesli started recording", body: meeting.candidate.title)
        } catch {
            setError("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func finishActiveSession(markInterrupted: Bool) async {
        guard var session = activeSession else { return }

        do {
            Logger.app.info("Finishing session for \(session.title, privacy: .public)")
            try await recorder.stop(session: &session)
            session.state = .transcribing
            session.interrupted = markInterrupted
            try await repository.persist(session)

            activeSession = session
            replaceSession(session)
            status = .transcribing
            await notifications.send(title: "Muesli stopped recording", body: session.title)

            try await transcriber.transcribe(session: &session)
            try await repository.persist(session)
            replaceSession(session)
            activeSession = nil
            status = armedMeetings.isEmpty ? .idle : .armed

            await notifications.send(title: "Transcript ready", body: session.title)
        } catch {
            session.state = .failed
            session.errorMessage = error.localizedDescription
            try? await repository.persist(session)
            replaceSession(session)
            activeSession = nil
            setError("Finishing session failed: \(error.localizedDescription)")
        }
    }

    private func retranscribe(_ originalSession: MeetingSession) async {
        guard originalSession.artifacts.mixedAudioPath != nil else {
            setError("Retry failed: no mixed audio was found for \(originalSession.title).")
            return
        }

        var session = originalSession
        session.state = .transcribing
        session.errorMessage = nil

        do {
            Logger.transcription.info("Retrying transcription for \(session.title, privacy: .public)")
            try await repository.persist(session)
            replaceSession(session)

            if activeSession == nil {
                status = .transcribing
            }

            try await transcriber.transcribe(session: &session)
            try await repository.persist(session)
            replaceSession(session)

            if activeSession == nil {
                status = armedMeetings.isEmpty ? .idle : .armed
            }

            await notifications.send(title: "Transcript ready", body: session.title)
        } catch {
            session.state = .failed
            session.errorMessage = error.localizedDescription
            try? await repository.persist(session)
            replaceSession(session)
            if activeSession == nil {
                setError("Retrying transcription failed: \(error.localizedDescription)")
            }
        }
    }

    private func replaceSession(_ updated: MeetingSession) {
        if let index = sessions.firstIndex(where: { $0.id == updated.id }) {
            sessions[index] = updated
        } else {
            sessions.insert(updated, at: 0)
        }
    }

    private func pollProvider(for meeting: ArmedMeeting, context: ProviderPollContext) async -> ProviderState {
        switch meeting.candidate.link.provider {
        case .googleMeet:
            await diaAdapter.pollState(for: meeting, context: context)
        case .gather:
            await gatherAdapter.pollState(for: meeting, context: context)
        case .manual:
            .inactive
        }
    }

    private func pollProvider(for session: MeetingSession, context: ProviderPollContext) async -> ProviderState {
        guard let canonicalMeetingURL = session.canonicalMeetingURL,
              let url = URL(string: canonicalMeetingURL),
              let canonical = MeetingURLExtractor.canonicalURL(for: url)
        else {
            return .inactive
        }

        let candidate = MeetingCandidate(
            eventIdentifier: session.meetingIdentifier,
            calendarTitle: "Unknown",
            title: session.title,
            startDate: session.scheduledStart,
            endDate: session.scheduledEnd,
            location: nil,
            notes: nil,
            link: MeetingLink(originalURL: url, canonicalURL: canonical, provider: session.provider)
        )
        let armedMeeting = ArmedMeeting(candidate: candidate, armStart: session.scheduledStart, armEnd: session.scheduledEnd.addingTimeInterval(settingsStore.settings.endGraceTime), canonicalMeetingKey: canonical.absoluteString)
        return await pollProvider(for: armedMeeting, context: context)
    }

    private func setError(_ message: String) {
        lastError = message
        status = .failed
        Logger.app.error("\(message, privacy: .public)")
    }

    private func logRequirementsIfNeeded() {
        let missing = requirements
            .filter { !$0.satisfied }
            .map(\.title)
            .sorted()
        let signature = missing.joined(separator: "|")

        guard signature != lastMissingRequirementSignature else { return }
        lastMissingRequirementSignature = signature

        if missing.isEmpty {
            Logger.permissions.info("All requirements satisfied")
        } else {
            let missingSummary = missing.joined(separator: ", ")
            Logger.permissions.info("Missing requirements: \(missingSummary, privacy: .public)")
        }
    }

    private func logArmedMeetingsIfNeeded() {
        let signature = armedMeetings
            .map(\.canonicalMeetingKey)
            .sorted()
            .joined(separator: "|")

        guard signature != lastArmedMeetingSignature else { return }
        lastArmedMeetingSignature = signature

        if armedMeetings.isEmpty {
            Logger.calendar.info("Armed meetings: none")
        } else {
            let titles = armedMeetings.map(\.candidate.title).joined(separator: ", ")
            Logger.calendar.info("Armed meetings: \(titles, privacy: .public)")
        }
    }
}
