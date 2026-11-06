import AVKit
import OSLog
import SwiftUI

/// Viewer-side playback for one live channel.
///
/// Uses AVPlayer on the provider's HLS (.m3u8) manifest: no extra dependency,
/// and standard HLS is enough for the viewer path end to end. The trade-off is
/// latency — roughly 5-15s on plain HLS — which matters for interactive tipping.
/// Cloudflare Stream also exposes a lower-latency WebRTC playback URL; adopting
/// it would only touch `videoSurface`.
struct WatchStreamView: View {
    let channel: LiveChannel

    @Environment(\.dismiss) private var dismiss
    @Environment(PaymentService.self) private var paymentService

    @State private var player: AVPlayer?
    @State private var isShowingTipSheet = false
    @State private var playbackFailed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            videoSurface

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

            if playbackFailed {
                playbackFailureOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await startPlayback() }
        .onDisappear {
            // Without this the audio keeps playing after the screen is gone.
            player?.pause()
            player = nil
            // Hand the session back so music the viewer had playing before
            // they opened the stream can resume.
            AudioSessionController.deactivate()
        }
        .sheet(isPresented: $isShowingTipSheet) {
            CreatorTipView(
                viewModel: CreatorTipViewModel(
                    payment: paymentService,
                    creatorID: channel.creatorID
                )
            )
        }
    }

    // MARK: - Video

    @ViewBuilder
    private var videoSurface: some View {
        if let player {
            VideoPlayer(player: player)
                .ignoresSafeArea()
        } else if !playbackFailed {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func startPlayback() async {
        let asset = AVURLAsset(url: channel.playbackURL)

        // Validate before handing it to a player. A creator who has just gone
        // offline leaves a URL that resolves but has no playable content, which
        // otherwise shows as an indefinite spinner rather than an error.
        do {
            guard try await asset.load(.isPlayable) else {
                playbackFailed = true
                return
            }
        } catch let failure where failure.isCancellation {
            // Leaving the screen cancels this load. That is not a dead stream,
            // and flagging it as one would show the failure state on the way
            // out — and again on the way back in.
            return
        } catch {
            AppLog.streaming.error("playback asset load failed: \(String(reflecting: error), privacy: .public)")
            playbackFailed = true
            return
        }

        guard !Task.isCancelled else { return }

        // Must happen before play(): the default category is `.soloAmbient`,
        // which mutes the stream whenever the ring/silent switch is on and
        // stops it at screen lock.
        AudioSessionController.activateForPlayback()

        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.allowsExternalPlayback = true
        player = newPlayer
        playbackFailed = false
        newPlayer.play()

        await observePlaybackFailure(for: item)
    }

    /// Catches a stream that dies mid-watch — the creator ending their broadcast
    /// is the common case, and without this the video just freezes.
    private func observePlaybackFailure(for item: AVPlayerItem) async {
        let failures = NotificationCenter.default.notifications(
            named: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item
        )

        for await _ in failures {
            playbackFailed = true
            return
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("LIVE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.9), in: Capsule())
            }

            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack {
            Spacer()

            Button {
                isShowingTipSheet = true
            } label: {
                Label("Send a Tip", systemImage: "gift.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(Color.pink.opacity(0.9), in: Capsule())
            }
        }
    }

    private var playbackFailureOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .accessibilityHidden(true)

            Text("Can’t play this stream")
                .font(.headline)
                .foregroundStyle(.white)

            Text("The creator may have just gone offline.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button("Try Again") {
                playbackFailed = false
                Task { await startPlayback() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white, in: Capsule())
        }
        .padding(32)
        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 40)
    }
}

#Preview {
    WatchStreamView(
        channel: LiveChannel(
            streamID: "stream1",
            creatorID: "creator1",
            displayName: "Preview Creator",
            startedAt: .now,
            playbackURL: URL(string: "https://example.com/stream.m3u8")!
        )
    )
    .environment(PaymentService())
}
