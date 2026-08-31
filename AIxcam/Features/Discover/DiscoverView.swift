import SwiftUI

/// Viewer-side live stream discovery feed. Currently there is no public stream
/// index, so the feed shows a live-empty state and refreshes on demand.
struct DiscoverView: View {
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    }
                    .padding(.horizontal, 24)
                }
                .refreshable { await refresh() }
            }
            .navigationTitle("Discover")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .cyan],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("No live streams right now")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            Text("When creators go live, their streams show up here. Pull down to refresh.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            if isRefreshing {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 4)
            }
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        // No public stream index yet; simulate a short refresh so the control
        // behaves correctly. Replace with a live-channels query when available.
        try? await Task.sleep(for: .seconds(1))
    }
}

#Preview {
    DiscoverView()
}
