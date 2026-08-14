import SwiftUI

struct LiveBroadcastView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: LiveBroadcastViewModel

    init(viewModel: LiveBroadcastViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            CameraPreviewView(
                session: viewModel.cameraManager.session,
                onTapToFocus: { devicePoint, layerPoint in
                    viewModel.focus(at: devicePoint, layerPoint: layerPoint)
                }
            )
            .ignoresSafeArea()

            backgroundAtmosphere

            LinearGradient(
                colors: [Color.black.opacity(0.78), Color.clear, Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar
                infrastructurePanel
                Spacer()
                chatOverlay
                tipOverlay
                controlBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

            if let focusPoint = viewModel.focusIndicatorPoint {
                FocusIndicatorView()
                    .position(focusPoint)
                    .allowsHitTesting(false)
            }

            if viewModel.isPreparing {
                ProgressView("Preparing stream...")
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(.white)
            }

            if !viewModel.hasPermission {
                permissionOverlay
            }

            if viewModel.isPrivacyShieldVisible {
                privacyShieldOverlay
            }
        }
        .background(Color.black)
        .task {
            await viewModel.onAppear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.handleAppBecameActive()
            case .inactive, .background:
                viewModel.handleAppBecameInactive()
            @unknown default:
                viewModel.handleAppBecameInactive()
            }
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .alert("Broadcast Error", isPresented: Binding(
            get: { viewModel.displayError != nil },
            set: { newValue in
                if !newValue {
                    viewModel.clearError()
                }
            }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.displayError ?? "Unknown error")
        }
    }

    private var backgroundAtmosphere: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -120, y: -280)

            Circle()
                .fill(Color.pink.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 65)
                .offset(x: 140, y: 250)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            statusBadge
            infrastructureBadge

            Spacer()

            Label("\(viewModel.viewerCount)", systemImage: "person.2.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill((viewModel.isLive ? Color.red : Color.gray).opacity(0.3))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(viewModel.isLive ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
            }

            Text(viewModel.liveBadgeTitle)
                .font(.caption.weight(.bold))
                .tracking(1.1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var infrastructureBadge: some View {
        Text(viewModel.infrastructureStatus.securityLevel.rawValue)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(infrastructureColor, in: Capsule())
    }

    private var infrastructureColor: Color {
        switch viewModel.infrastructureStatus.securityLevel {
        case .initializing:
            return Color.orange.opacity(0.75)
        case .secure:
            return Color.green.opacity(0.75)
        case .degraded:
            return Color.red.opacity(0.75)
        }
    }

    private var infrastructurePanel: some View {
        HStack(spacing: 10) {
            Text(viewModel.infrastructureStatus.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)

            Spacer()

            if viewModel.infrastructureStatus.securityLevel == .degraded {
                Button("Retry") {
                    Task {
                        await viewModel.retryInfrastructure()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var chatOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Chat")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            VStack(alignment: .leading, spacing: 6) {
                Text("@LuxeFan: This stream quality is elite")
                Text("@WaveRider: Front cam looks clean")
                Text("@NovaTips: Sending tips soon")
            }
            .font(.footnote)
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tipOverlay: some View {
        Group {
            if viewModel.isAnimatingTip {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("Tip received")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.6), Color.pink.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: viewModel.isAnimatingTip)
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.flipCamera()
            } label: {
                controlIcon("arrow.triangle.2.circlepath.camera")
            }
            .disabled(!viewModel.hasPermission || viewModel.isPreparing || viewModel.isPrivacyShieldVisible)

            Button {
                viewModel.toggleMicrophone()
            } label: {
                controlIcon(viewModel.cameraManager.isMuted ? "mic.slash.fill" : "mic.fill")
            }
            .disabled(!viewModel.hasPermission || viewModel.isPreparing || viewModel.isPrivacyShieldVisible)

            zoomPill

            Spacer()

            Button {
                Task {
                    if viewModel.isLive {
                        await viewModel.endLive()
                    } else {
                        await viewModel.goLive()
                    }
                }
            } label: {
                Text(viewModel.isLive ? "End Live" : "Go Live")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        viewModel.isLive ? Color.red.opacity(0.9) : Color.pink.opacity(0.9),
                        in: Capsule()
                    )
            }
            .disabled(viewModel.isLive ? !viewModel.canEndLive : !viewModel.canStartLive)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.38))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        }
    }

    private var zoomPill: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: "%.1fx", viewModel.zoomFactor))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))

            Slider(
                value: Binding(
                    get: { viewModel.zoomFactor },
                    set: { viewModel.setZoom($0) }
                ),
                in: 1.0...viewModel.maxZoomFactor
            )
            .frame(width: 92)
            .tint(.white)
        }
        .padding(.horizontal, 8)
    }

    private var permissionOverlay: some View {
        VStack(spacing: 12) {
            Text("Camera + Microphone Access Required")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Enable permissions in Settings to start a livestream.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.15), in: Capsule())
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(24)
    }

    private var privacyShieldOverlay: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text("Privacy Shield Enabled")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Camera stream paused while app is not active.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
    }

    private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(Color.white.opacity(0.12), in: Circle())
    }
}

private struct FocusIndicatorView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color.yellow.opacity(0.95), lineWidth: 2)
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.yellow.opacity(0.08))
            )
            .transition(.scale.combined(with: .opacity))
            .animation(.easeOut(duration: 0.18), value: UUID())
    }
}

#Preview {
    LiveBroadcastView(
        viewModel: LiveBroadcastViewModel(creatorID: "preview-creator")
    )
}
