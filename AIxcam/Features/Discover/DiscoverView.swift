import SwiftUI

/// Viewer-side live stream discovery feed.
///
/// The list is assembled by the `listLiveChannels` Cloud Function rather than a
/// direct Firestore query: `streams/{id}` is readable only by its owning
/// creator, and the playback URL lives in `creatorChannels/{uid}`, which is
/// closed to clients because it also holds the RTMP stream key.
struct DiscoverView: View {
    @State private var service = LiveChannelService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                content
            }
            .navigationTitle("Discover")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            // Only on first appearance; pull-to-refresh covers the rest.
            guard !service.hasLoadedOnce else { return }
            await service.refresh()
        }
    }

    @ViewBuilder
    private var content: some View {
        if service.channels.isEmpty {
            ScrollView {
                emptyOrErrorState
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                    .padding(.horizontal, 24)
            }
            .refreshable { await service.refresh() }
        } else {
            List(service.channels) { channel in
                NavigationLink {
                    WatchStreamView(channel: channel)
                } label: {
                    channelRow(channel)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await service.refresh() }
        }
    }

    // MARK: - Rows

    private func channelRow(_ channel: LiveChannel) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.pink.opacity(0.5), .cyan.opacity(0.5)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 46, height: 46)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(channel.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let startedAt = channel.startedAt {
                    Text("Live for \(Self.elapsed(since: startedAt))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            Text("LIVE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.9), in: Capsule())
        }
        .padding(.vertical, 6)
    }

    /// Compact "how long they've been on air", e.g. 12m or 1h 04m.
    static func elapsed(since start: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "just now"
    }

    // MARK: - Empty / error

    @ViewBuilder
    private var emptyOrErrorState: some View {
        if service.loadFailed {
            stateBlock(
                icon: "wifi.exclamationmark",
                title: "Couldn’t load live streams",
                detail: "Check your connection and pull down to try again."
            )
        } else if service.isLoading && !service.hasLoadedOnce {
            ProgressView()
                .tint(.white)
                .padding(.top, 40)
        } else {
            stateBlock(
                icon: "dot.radiowaves.left.and.right",
                title: "No live streams right now",
                detail: "When creators go live, their streams show up here. Pull down to refresh."
            )
        }
    }

    private func stateBlock(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .cyan],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Live channels") {
    DiscoverView()
        .environment(PaymentService())
}
