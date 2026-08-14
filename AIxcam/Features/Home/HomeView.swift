import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                atmosphereBlurs

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        NavigationLink {
                            LiveBroadcastView(
                                viewModel: LiveBroadcastViewModel(creatorID: "creator-demo")
                            )
                            .toolbar(.hidden, for: .navigationBar)
                        } label: {
                            goLiveCard
                        }

                        pastStreamsPlaceholder
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var atmosphereBlurs: some View {
        ZStack {
            Circle()
                .fill(Color.pink.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 130, y: -180)

            Circle()
                .fill(Color.cyan.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 65)
                .offset(x: -120, y: 200)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hello, Creator")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
            Text("Ready to go live?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var goLiveCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink, .red.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Start Live Stream")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Stream setup → Stage 3")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.13), lineWidth: 1)
                )
        )
    }

    private var pastStreamsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Streams")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Your stream history will appear here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.38))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundStyle(Color.white.opacity(0.1))
                        )
                )
        }
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
}
