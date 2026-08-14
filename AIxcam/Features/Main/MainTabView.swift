import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home, discover, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "play.rectangle.on.rectangle.fill")
                }
                .tag(Tab.discover)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)
        }
        .tint(.pink)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
        .environment(AppRouter())
}
