import FirebaseAuth
import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var historyService = StreamHistoryService()

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
                                viewModel: LiveBroadcastViewModel(creatorID: appRouter.currentUser?.uid ?? "")
                            )
                            .toolbar(.hidden, for: .navigationBar)
                        } label: {
                            goLiveCard
                        }

                        pastStreamsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard let uid = appRouter.currentUser?.uid, !uid.isEmpty else { return }
                Task { await historyService.fetchHistory(creatorID: uid) }
            }
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
            Text("Hello, \(appRouter.displayName)")
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
                Text("Camera, mic & live chat")
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

    private var pastStreamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Streams")
                .font(.headline)
                .foregroundStyle(.white)

            if historyService.isLoading && historyService.recentStreams.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else if historyService.recentStreams.isEmpty {
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
            } else {
                VStack(spacing: 10) {
                    ForEach(historyService.recentStreams) { record in
                        streamRecordRow(record)
                    }
                }
            }
        }
    }

    private func streamRecordRow(_ record: StreamRecord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 42, height: 42)
                Image(systemName: "play.rectangle.fill")
                    .font(.callout)
                    .foregroundStyle(.pink.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.formattedDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(record.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Label("\(record.peakViewers)", systemImage: "person.2.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
}
