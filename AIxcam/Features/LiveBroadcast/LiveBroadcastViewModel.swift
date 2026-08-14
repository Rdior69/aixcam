import CoreGraphics
import Foundation
import Observation

@Observable
@MainActor
final class LiveBroadcastViewModel {
    var isLive = false
    var viewerCount = 0
    var hasPermission = true
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

    private let streamingService: StreamingService
    private let creatorID: String
    private var broadcastSession: BroadcastSession?
    private var viewerTask: Task<Void, Never>?
    private var infrastructureTask: Task<Result<StreamingInfrastructureStatus, Error>, Never>?

    var displayError: String? {
        errorMessage ?? cameraManager.errorMessage
    }

    init(
        creatorID: String,
        cameraManager: CameraManager? = nil,
        streamingService: StreamingService? = nil
    ) {
        self.creatorID = creatorID
        self.cameraManager = cameraManager ?? CameraManager()
        self.streamingService = streamingService ?? MockStreamingService()
    }

    var liveBadgeTitle: String {
        isLive ? "LIVE" : "OFFLINE"
    }

    var zoomFactor: CGFloat {
        cameraManager.zoomFactor
    }

    var maxZoomFactor: CGFloat {
        max(cameraManager.maxZoomFactor, 1.0)
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
        infrastructureTask?.cancel()

        if isLive {
            Task {
                await endLive()
            }
        }

        cameraManager.stopSession()
    }

    func handleAppBecameInactive() {
        isPrivacyShieldVisible = true
        focusIndicatorPoint = nil
        infrastructureTask?.cancel()
        cameraManager.stopSession()

        if isLive {
            Task {
                await endLive()
            }
        }
    }

    func handleAppBecameActive() {
        isPrivacyShieldVisible = false
        guard hasPermission else { return }
        cameraManager.startSession()

        Task {
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
            viewerCount = 12
            startViewerSimulation()
            triggerTipPlaceholder()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endLive() async {
        guard isLive else { return }

        isPreparing = true
        defer { isPreparing = false }

        do {
            if let broadcastSession {
                try await streamingService.endBroadcast(streamID: broadcastSession.streamID)
            }

            isLive = false
            broadcastSession = nil
            viewerCount = 0
            viewerTask?.cancel()
            isAnimatingTip = false
        } catch {
            errorMessage = error.localizedDescription
        }
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

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self else { return }
            guard !Task.isCancelled else { return }
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
        if !forceRefresh && infrastructureStatus.isReady {
            return
        }

        if let existingTask = infrastructureTask {
            _ = await existingTask.value
            return
        }

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
            guard let self else { return }
            guard !Task.isCancelled else { return }
            self.isAnimatingTip = false
        }
    }
}
