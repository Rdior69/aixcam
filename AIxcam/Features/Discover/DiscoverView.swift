import SwiftUI

/// Viewer-side live stream discovery feed.
/// Full implementation in Stage 6 (DiscoverService + StreamPlayerView).
struct DiscoverView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))

                Text("Discover Live Streams")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.5))

                Text("Live stream browsing and in-app\nplayback arrive in Stage 6.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    DiscoverView()
}
