import SwiftUI

@main
struct LoverApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .theme(.jbeam)   // single launch theme; other themes are post-v1.0
                .task { await session.bootstrap() }
        }
    }
}

// Top-level routing. Decides which surface to show based on auth + pairing state.
// Onboarding and Pairing screens land in v0.1; for now they short-circuit to the
// paired tab view so the chat UI can be exercised end-to-end.
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        switch session.state {
        case .loading:
            ProgressView()
        case .signedOut:
            // TODO v0.1: OnboardingView()
            MainTabView()
        case .signedInUnpaired:
            // TODO v0.1: PairingView()
            MainTabView()
        case .paired:
            MainTabView()
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedInUnpaired
        case paired(coupleId: UUID, partnerUserId: UUID)
    }

    @Published private(set) var state: State = .loading

    func bootstrap() async {
        // v0.1 wires this to KeyManager + BackendClient. For now we drop straight
        // into the paired state so the chat UI can be developed and reviewed.
        state = .paired(coupleId: UUID(), partnerUserId: UUID())
    }
}
