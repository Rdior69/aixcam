import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var appRouter

    var body: some View {
        if appRouter.isAuthenticated {
            MainTabView()
        } else {
            NavigationStack {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
