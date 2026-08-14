import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class LiveBroadcastViewModel {
    enum BroadcastState {
        case setup
        case broadcasting
        case ended
    }
    
    private(set) var state: BroadcastState = .setup
    private(set) var viewerCount: Int = 0
    private(set) var duration: TimeInterval = 0
    private(set) var streamTitle: String = ""
    private(set) var streamDescription: String = ""
    
    let creatorID: String
    let cameraManager: CameraManager
    
    private var durationTimer: Timer?
    
    init(creatorID: String) {
        self.creatorID = creatorID
        self.cameraManager = CameraManager()
    }
    
    deinit {
        stopBroadcast()
    }
    
    func updateStreamInfo(title: String, description: String) {
        self.streamTitle = title
        self.streamDescription = description
    }
    
    func startBroadcast() {
        guard state == .setup else { return }
        
        state = .broadcasting
        duration = 0
        
        // Start camera session
        cameraManager.configureIfNeeded()
        cameraManager.startSession()
        
        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.duration += 1
            }
        }
        
        // TODO: Initialize actual streaming connection (Stage 3+)
        // This would connect to your streaming backend/service
        
        // Simulate viewer count changes for demo
        simulateViewerActivity()
    }
    
    func stopBroadcast() {
        guard state == .broadcasting else { return }
        
        state = .ended
        
        // Stop camera
        cameraManager.stopSession()
        
        // Stop timer
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    func toggleMute() {
        cameraManager.toggleMute()
    }
    
    func flipCamera() {
        cameraManager.flipCamera()
    }
    
    func updateZoom(_ factor: CGFloat) {
        cameraManager.setZoom(factor)
    }
    
    // MARK: - Private Helpers
    
    private func simulateViewerActivity() {
        // Simple simulation for testing - replace with real viewer tracking
        Task {
            while state == .broadcasting {
                try? await Task.sleep(for: .seconds(Double.random(in: 3...8)))
                guard state == .broadcasting else { break }
                
                let change = Int.random(in: -2...5)
                viewerCount = max(0, viewerCount + change)
            }
        }
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
