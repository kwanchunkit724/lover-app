import SwiftUI
import AuthenticationServices

// Shown after onboarding when there's no Supabase session. Single button:
// native Sign in with Apple. Once signed in, AuthService transitions state
// and RootView swaps to the (Phase 3b) PairingView, or — for now — directly
// to MainTabView via the placeholder PairingPlaceholderView.

struct SignInView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Text("(´｡• ω •｡`)")
                    .font(.system(size: 48, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.rose)

                Text("差啲就好")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)

                Text("用 Apple 登入，\n之後就可以同對方配對。")
                    .font(DSText.ui(theme, 14))
                    .foregroundStyle(theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()

                if case .error(let msg) = auth.state {
                    Text(msg)
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.rose)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                SignInWithAppleButton(.signIn,
                    onRequest: auth.configureAppleRequest,
                    onCompletion: { result in
                        Task {
                            guard let p = profileStore.profile else { return }
                            await auth.handleAppleResult(result, profile: p)
                        }
                    }
                )
                .signInWithAppleButtonStyle(theme.isDark ? .white : .black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

// MARK: - Placeholder unpaired surface

/// Shown after sign-in but before pairing. Phase 3b replaces this with the
/// real PairingView (generate code / enter code, with anniversary cross-check).
struct PairingPlaceholderView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Text("(◕‿◕)")
                    .font(.system(size: 48, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.rose)

                Text("已登入")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)

                Text("Phase 3b 會做配對流程：\n你會攞到一個 6 位數字配對碼，畀對方輸入。")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let name = profileStore.profile?.myName {
                    Text("hi, \(name) ♡")
                        .font(DSText.mono(theme, 13))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.top, 8)
                }

                Spacer()

                Button {
                    Task { await auth.signOut() }
                } label: {
                    Text("登出")
                        .font(DSText.ui(theme, 14, weight: .medium))
                        .foregroundStyle(theme.inkSoft)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.line, lineWidth: 0.5)
                        )
                }
                .padding(.bottom, 28)
            }
        }
    }
}

#Preview("Sign in") {
    SignInView()
        .environmentObject(UserProfileStore())
        .environmentObject(AuthService())
        .theme(.jbeam)
}

#Preview("Placeholder paired") {
    PairingPlaceholderView()
        .environmentObject(UserProfileStore())
        .environmentObject(AuthService())
        .theme(.jbeam)
}
