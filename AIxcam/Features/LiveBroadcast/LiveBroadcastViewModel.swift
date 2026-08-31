import CoreGraphics
import Foundation
import Observation

@Observable
@MainActor
final class LiveBroadcastViewModel {
    var isLive = false
    var viewerCount = 0
    var hasPermission = false
    var isPreparing = false
    var isAnimatingTip = false
    var errorMessage: String?
    var focusIndicatorPoint: CGPoint?
    var isPrivacyShieldVisible = false
    var infrastructureStatus = StreamingInfrastructureStatus(
        isReady: false,
        securityLevel: .initializing,
        description: "Preparing infrastructure"
    )

    let cameraManager: CameraManager
    private(set) var chatService = ChatService()

    private let streamingService: StreamingService
    private let historyService = StreamHistoryService()
    private let creatorID: String
    private var broadcastSession: BroadcastSession?
    private var currentStreamDocumentID: String?
    private var peakViewerCount = 0
    private var viewerTask: Task<Void, Never>?
    private var focusTask: Task<Void, Never>?
    private var infrastructureTask: Task<Result<StreamingInfrastructureStatus, Error>, Never>?
    private var infrastructureGeneration: UInt = 0

    var displayError: String? {
        errorMessage ?? cameraManager.errorMessage
    }

    var chatMessages: [ChatMessage] { chatService.messages }
    var isChatConnected: Bool { chatService.isConnected }

    init(
        creatorID: String,
        cameraManager: CameraManager? = nil,
        streamingService: StreamingService? = nil
    ) {
        self.creatorID = creatorID
        let cm = cameraManager ?? CameraManager()
        self.cameraManager = cm
        self.streamingService = streamingService ?? IVSStreamingService(
            credentialsProvider: FirebaseStreamCredentialsService(),
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
        hasPermission && infrastructureStatus.isReady && !isPreparing && !isPrivacyShieldVisible
    }

    var canEndLive: Bool {
        isLive && !isPreparing
    }

    func onAppear() async {
        await requestPermissionsAndPrepareCamera()
        await ensureInfrastructurePrepared(forceRefresh: false)
    }

    func onDisappear() {
        viewerTask?.cancel()
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
            errorMessage = "Secure streaming infrastructure is still initializing."
            await ensureInfrastructurePrepared(forceRefresh: false)
            return
        }

        isPreparing = true
        defer { isPreparing = false }

        do {
            broadcastSession = try await streamingService.startBroadcast(creatorID: creatorID)
            isLive = true
            viewerCount = 0
            peakViewerCount = 0
            startViewerSimulation() // TODO: Replace with real IVS GetStream viewer count polling.
            triggerTipPlaceholder()
            currentStreamDocumentID = await historyService.startSession(creatorID: creatorID)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // Connect to chat after broadcast starts — failure doesn't abort the stream.
        do {
            try await chatService.connect(roomARN: streamingService.chatRoomARN)
        } catch {
            // Chat is non-critical; swallow the error silently.
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
            viewerCount = 0
            viewerTask?.cancel()
            isAnimatingTip = false
            broadcastEnded = true
        } catch {
            errorMessage = error.localizedDescription
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

    func clearError() {
        errorMessage = nil
        cameraManager.clearError()
    }

    private func requestPermissionsAndPrepareCamera() async {
        hasPermission = await PermissionManager.requestCameraAndMicrophoneAccess()

        guard hasPermission else {
            errorMessage = "Camera and microphone access are required to go live."
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
        case .failure:
            infrastructureStatus = StreamingInfrastructureStatus(
                isReady: false,
                securityLevel: .degraded,
                description: "Infrastructure unavailable"
            )
            errorMessage = "Could not initialize secure streaming infrastructure."
        }
    }

    private func startViewerSimulation() {
        viewerTask?.cancel()

        viewerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                guard self.isLive else { return }

                let delta = Int.random(in: -2 ... 8)
                self.viewerCount = max(0, self.viewerCount + delta)
                if self.viewerCount > self.peakViewerCount {
                    self.peakViewerCount = self.viewerCount
                }

                if Int.random(in: 0 ... 4) == 0 {
                    self.triggerTipPlaceholder()
                }
            }
        }
    }

    private func triggerTipPlaceholder() {
        isAnimatingTip = true

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(950))
            guard let self, !Task.isCancelled else { return }
            self.isAnimatingTip = false
        }
    }
}
