import AVFoundation
import SwiftUI

struct LiveCameraStudioView: View {
    @StateObject private var viewModel: LiveCameraViewModel
    let onClose: () -> Void

    init(creatorDisplayName: String, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LiveCameraViewModel(creatorDisplayName: creatorDisplayName))
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.authorization == .authorized, viewModel.isSessionRunning {
                LiveCameraPreview(session: viewModel.sessionController.session)
                    .ignoresSafeArea()
            } else {
                placeholderBackground
            }

            VStack(spacing: 0) {
                topChrome
                Spacer()
                bottomChrome
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .statusBarHidden(viewModel.phase == .live)
        .task {
            await viewModel.requestAccessAndPrepare()
        }
        .onDisappear {
            viewModel.closeStudio()
        }
    }

    private var placeholderBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.14),
                    Color(red: 0.08, green: 0.12, blue: 0.2),
                    Color(red: 0.12, green: 0.1, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "video.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.teal)
                Text(placeholderTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(placeholderSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if viewModel.authorization == .notDetermined || viewModel.authorization == .denied {
                    Button("Enable camera") {
                        Task { await viewModel.requestAccessAndPrepare() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                }
            }
        }
    }

    private var placeholderTitle: String {
        switch viewModel.authorization {
        case .authorized:
            return viewModel.errorMessage.isEmpty ? "Preparing camera…" : "Camera unavailable"
        case .denied, .restricted:
            return "Camera access needed"
        case .notDetermined:
            return "Allow camera access"
        }
    }

    private var placeholderSubtitle: String {
        if viewModel.errorMessage.isEmpty == false {
            return viewModel.errorMessage
        }
        switch viewModel.authorization {
        case .authorized:
            return "Hang tight while Aixcam connects your camera."
        case .denied, .restricted:
            return "Open Settings → Aixcam and enable Camera to go live."
        case .notDetermined:
            return "Aixcam uses the camera and mic for creator livestreams."
        }
    }

    private var topChrome: some View {
        HStack(alignment: .top) {
            Button {
                viewModel.closeStudio()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45), in: Circle())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if viewModel.phase == .live {
                    HStack(spacing: 8) {
                        Text("LIVE")
                            .font(.caption.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red, in: Capsule())
                        Text(viewModel.elapsedLabel)
                            .font(.caption.monospacedDigit().weight(.semibold))
                        Label("\(viewModel.simulatedViewers)", systemImage: "eye.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Text(viewModel.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.35), in: Capsule())
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
    }

    private var bottomChrome: some View {
        VStack(spacing: 14) {
            if viewModel.statusMessage.isEmpty == false {
                Text(viewModel.statusMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.4), in: Capsule())
                    .transition(.opacity)
            }

            if viewModel.errorMessage.isEmpty == false, viewModel.authorization == .authorized {
                Text(viewModel.errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 18) {
                controlButton(
                    systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill",
                    label: viewModel.isMuted ? "Unmute" : "Mute"
                ) {
                    viewModel.toggleMute()
                }

                if viewModel.phase == .live {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.endLive()
                        }
                    } label: {
                        Text("End live")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            viewModel.goLive()
                        }
                    } label: {
                        Text(viewModel.phase == .ended ? "Go live again" : "Go live")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(viewModel.authorization != .authorized && viewModel.authorization != .notDetermined)
                }

                controlButton(systemName: "arrow.triangle.2.circlepath.camera", label: "Flip") {
                    viewModel.flipCamera()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
    }

    private func controlButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.title3.weight(.semibold))
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct LiveCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
