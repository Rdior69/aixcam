import Combine
import Foundation
import SwiftUI

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var rootRoute: AppRootRoute = .launching
    @Published private(set) var isBootstrapping = true

    let authViewModel: AuthViewModel

    private var cancellables = Set<AnyCancellable>()
    private var hasCompletedBootstrap = false

    init(authViewModel: AuthViewModel = AuthViewModel(restoreSessionOnInit: false)) {
        self.authViewModel = authViewModel
        bindAuthChanges()
    }

    func bootstrap() async {
        // Only run cold-start once. Presenting signup/login covers can restart
        // RootView `.task`; re-running revalidate here was restoring a stale
        // session and jumping users straight to account home.
        guard hasCompletedBootstrap == false else { return }

        isBootstrapping = true
        rootRoute = .launching

        // Brief launch frame so cold starts always show the splash route.
        try? await Task.sleep(nanoseconds: 350_000_000)
        await authViewModel.revalidateSession()
        refreshRoute()
        isBootstrapping = false
        hasCompletedBootstrap = true
    }

    func refreshRoute() {
        rootRoute = SessionRouter.route(for: authViewModel.currentUser)
    }

    private func bindAuthChanges() {
        authViewModel.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isBootstrapping == false else { return }
                self.refreshRoute()
            }
            .store(in: &cancellables)
    }
}
