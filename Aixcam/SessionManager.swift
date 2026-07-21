import Combine
import Foundation
import SwiftUI

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var rootRoute: AppRootRoute = .launching
    @Published private(set) var isBootstrapping = true

    let authViewModel: AuthViewModel

    private var cancellables = Set<AnyCancellable>()

    init(authViewModel: AuthViewModel = AuthViewModel(restoreSessionOnInit: false)) {
        self.authViewModel = authViewModel
        bindAuthChanges()
    }

    func bootstrap() async {
        isBootstrapping = true
        rootRoute = .launching

        // Brief launch frame so cold starts always show the splash route.
        try? await Task.sleep(nanoseconds: 350_000_000)
        await authViewModel.revalidateSession()
        refreshRoute()
        isBootstrapping = false
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
