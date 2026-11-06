import CoreGraphics
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class LiveBroadcastViewModel {
    var isLive = false
    /// nil while the real count is unknown, which is currently always. Modelled
    /// as optional rather than 0 so the UI can say "unknown" instead of
    /// asserting that nobody is watching.
    var viewerCount: Int?
    var hasPermission = false
    var isPreparing = false
    var isAnimatingTip = false
    var error: AppError?
    var focusIndicatorPoint: CGPoint?
    var isPrivacyShieldVisible = false
    var infrastructureStatus = StreamingInfrastructureStatus(
        isReady: false,
        securityLevel: .initializing,
        description: "Preparing infrastructure"
    )

    let cameraManager: CameraManager
    private(set) var chatService = ChatService()

    private let streamingService: StreamingServicing
    private let historyService: StreamHistoryService
    private let creatorID: String
    private var broadcastSession: BroadcastSession?
    private var currentStreamDocumentID: String?
    private var peakViewerCount = 0
    private var focusTask: Task<Void, Never>?
    private var infrastructureTask: Task<Result<StreamingInfrastructureStatus, Error>, Never>?
    private var infrastructureGeneration: UInt = 0

    /// The single error the screen presents.
    ///
    /// Two sources feed it. The camera's is shown only when the broadcast
    /// itself has nothing to report, so a "can't go live" message is never
    /// buried under a stale focus or zoom failure. Clearing it clears both —
    /// otherwise dismissing one alert immediately presents the other.
    var displayedError: AppError? {
        get { error ?? cameraManager.error }
        set {
            if newValue == nil {
                clearError()
            } else {
                error = newValue
            }
        }
    }

    var chatMessages: [ChatMessage] { chatService.messages }
    var isChatConnected: Bool { chatService.isConnected }

    init(
        creatorID: String,
        cameraManager: CameraManager? = nil,
        streamingService: StreamingServicing? = nil,
        // Optional rather than a default value because StreamHistoryService is
        // @MainActor, and default arguments are evaluated outside any actor.
        historyService: StreamHistoryService? = nil
    ) {
        self.creatorID = creatorID
        self.historyService = historyService ?? StreamHistoryService()
        let cm = cameraManager ?? CameraManager()
        self.cameraManager = cm
        self.streamingService = streamingService ?? LiveStreamingService(
            credentialsProvider: FirebaseStreamCredentialsProvider(),
            cameraManager: cm
        )
    }

    var liveBadgeTitle: String {
        isLive ? "LIVE" : "OFFLINE"
    }

    var zoomFactor: CGFloat {
        cameraManager.zoomFactor
    }

    var maxZoomFactor: CGFloat {
        // Floor at 1.01, not 1.0: a Slider with a zero-width 1.0...1.0 range
        // triggers a preconditionFailure in SwiftUI's layout engine.
        max(cameraManager.maxZoomFactor, 1.01)
    }

    var canStartLive: Bool {
        hasPermission
        && infrastructureStatus.isReady
        && !isPreparing
        && !isPrivacyShieldVisible
    }

    var canEndLive: Bool {
        isLive && !isPreparing
    }

    func onAppear() async {
        await requestPermissionsAndPrepareCamera()
        await ensureInfrastructurePrepared(forceRefresh: false)
    }

    func onDisappear() {
        focusTask?.cancel()
        infrastructureTask?.cancel()
        chatService.disconnect()

        if isLive {
            Task { await endLive() }
        }

        cameraManager.stopSession()
    }

    func handleAppBecameInactive() {
        isPrivacyShieldVisible = true
        focusIndicatorPoint = nil
        infrastructureTask?.cancel()
        cameraManager.stopSession()

        if isLive {
            Task { await endLive() }
        }
    }

    func handleAppBecameActive() {
        isPrivacyShieldVisible = false
        // Re-run the full permission check rather than trusting the (possibly
        // stale) hasPermission flag: a user may have just granted access in
        // Settings, in which case we must clear the overlay and start the camera.
        Task {
            await requestPermissionsAndPrepareCamera()
            await ensureInfrastructurePrepared(forceRefresh: false)
        }
    }

    func retryInfrastructure() async {
        await ensureInfrastructurePrepared(forceRefresh: true)
    }

    func goLive() async {
        guard hasPermission else { return }
        guard !isLive else { return }

        guard infrastructureStatus.isReady else {
            error = AppError(message: String(localized: "Secure streaming infrastructure is still initializing."))
            await ensureInfrastructurePrepared(forceRefresh: false)
            return
        }

        isPreparing = true
        defer { isPreparing = false }

        do {
            broadcastSession = try await streamingService.startBroadcast(creatorID: creatorID)
            isLive = true
            // Stays nil until real viewer counts are wired up (Cloudflare
            // Stream's live-input analytics). It used to be seeded by a random
            // walk whose peaks were written into the stream history document as
            // if they were real.
            viewerCount = nil
            peakViewerCount = 0
            currentStreamDocumentID = await historyService.startSession(creatorID: creatorID)
        } catch {
            report(error)
            return
        }

        // Connect to chat after broadcast starts — failure doesn't abort the stream.
        do {
            guard let streamID = currentStreamDocumentID else { return }
            try await chatService.connect(streamID: streamID)
        } catch {
            // Chat is non-critical: the creator is live and their audience can
            // watch. Interrupting a broadcast that just started, over a side
            // channel, would cost more than the missing chat does.
            AppLog.streaming.error("chat connect failed: \(String(reflecting: error), privacy: .public)")
        }
    }

    func endLive() async {
        guard isLive else { return }

        isPreparing = true
        defer { isPreparing = false }

        chatService.disconnect()

        let savedDocumentID = currentStreamDocumentID
        let savedPeak = peakViewerCount

        var broadcastEnded = false
        do {
            if let broadcastSession {
                try await streamingService.endBroadcast(streamID: broadcastSession.streamID)
            }

            isLive = false
            broadcastSession = nil
            currentStreamDocumentID = nil
            peakViewerCount = 0
            viewerCount = nil
            isAnimatingTip = false
            broadcastEnded = true
        } catch {
            report(error)
        }

        if broadcastEnded, let docID = savedDocumentID {
            await historyService.endSession(documentID: docID, peakViewers: savedPeak)
        }
    }

    func sendChatMessage(_ text: String) {
        chatService.send(text)
    }

    func flipCamera() {
        cameraManager.flipCamera()
    }

    func toggleMicrophone() {
        cameraManager.toggleMute()
    }

    func setZoom(_ value: CGFloat) {
        cameraManager.setZoomFactor(value)
    }

    func focus(at devicePoint: CGPoint, layerPoint: CGPoint) {
        cameraManager.focus(at: devicePoint)
        focusIndicatorPoint = layerPoint

        focusTask?.cancel()
        focusTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            self.focusIndicatorPoint = nil
        }
    }

    /// Clears both sources behind `displayedError`, so one dismissal doesn't
    /// immediately re-present the other one.
    func clearError() {
        error = nil
        cameraManager.clearError()
    }

    /// Records a failure for the UI and logs the detail.
    private func report(_ failure: Error) {
        guard let presentable = AppError.presentable(failure) else { return }
        error = presentable
        AppLog.streaming.error("\(presentable.diagnostic, privacy: .public)")
    }

    private func requestPermissionsAndPrepareCamera() async {
        hasPermission = await PermissionManager.requestCameraAndMicrophoneAccess()

        guard hasPermission else {
            error = AppError(message: String(localized: "Camera and microphone access are required to go live."))
            return
        }

        cameraManager.startSession()
    }

    private func ensureInfrastructurePrepared(forceRefresh: Bool) async {
        if !forceRefresh && infrastructureStatus.isReady { return }

        if let existingTask = infrastructureTask {
            if forceRefresh {
                // Cancel the stale attempt and fall through to start a fresh one.
                existingTask.cancel()
                infrastructureTask = nil
            } else {
                _ = await existingTask.value
                return
            }
        }

        // Stamp this attempt so a stale cancelled task can't overwrite a newer result.
        // Without this guard, Task A (cancelled by retry) can complete after Task B
        // and silently overwrite Task B's correctly-updated state.
        infrastructureGeneration &+= 1
        let myGeneration = infrastructureGeneration

        infrastructureStatus = StreamingInfrastructureStatus(
            isReady: false,
            securityLevel: .initializing,
            description: "Preparing infrastructure"
        )

        let task = Task<Result<StreamingInfrastructureStatus, Error>, Never> {
            do {
                let status = try await streamingService.prepareInfrastructure()
                return .success(status)
            } catch {
                return .failure(error)
            }
        }

        infrastructureTask = task
        let result = await task.value
        infrastructureTask = nil

        guard infrastructureGeneration == myGeneration else { return }

        switch result {
        case .success(let status):
            infrastructureStatus = status
        case .failure(let failure):
            infrastructureStatus = StreamingInfrastructureStatus(
                isReady: false,
                securityLevel: .degraded,
                description: "Infrastructure unavailable"
            )
            AppLog.streaming.error("infrastructure prepare failed: \(String(reflecting: failure), privacy: .public)")
            // Deliberately not the underlying error's wording: the recovery the
            // creator needs is "retry", which the degraded status already
            // offers, and transport detail here would only confuse that.
            error = AppError(message: String(localized: "Could not initialize secure streaming infrastructure."))
        }
    }

    /// Plays the tip celebration overlay.
    ///
    /// Call this when a *real* tip arrives. It used to be driven by a random
    /// timer alongside the viewer simulation, which meant the overlay fired for
    /// tips that had never happened.
    func showTipCelebration() {
        isAnimatingTip = true

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(950))
            guard let self, !Task.isCancelled else { return }
            self.isAnimatingTip = false
        }
    }
}
