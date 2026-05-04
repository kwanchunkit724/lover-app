import SwiftUI
import AuthenticationServices

// Phase 8 v0.8.0 — multi-method sign-in.
// Two ways to sign in:
//   • Sign in with Apple (native sheet)
//   • Email magic link / OTP (Supabase Email auth)
//
// Apple's App Review rule: any app offering third-party social login MUST
// also offer Sign in with Apple. We always show the Apple button first.

struct SignInView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService

    @State private var showEmailFlow: Bool = false
    @State private var emailDraft: String = ""
    @State private var otpDraft: String = ""
    @State private var isSubmitting: Bool = false

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

                Text("登入之後就可以同對方配對。")
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

                signInArea
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Sign-in area

    @ViewBuilder
    private var signInArea: some View {
        if let pending = auth.emailLinkSent {
            otpEntryFlow(forEmail: pending)
        } else if showEmailFlow {
            emailEntryFlow
        } else {
            primaryButtons
        }
    }

    /// Default: Apple button + "Email 都得" alternative.
    private var primaryButtons: some View {
        VStack(spacing: 10) {
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

            HStack(spacing: 8) {
                Rectangle().fill(theme.line).frame(height: 0.5)
                Text("或")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
                Rectangle().fill(theme.line).frame(height: 0.5)
            }
            .padding(.vertical, 4)

            Button { withAnimation(.easeInOut(duration: 0.2)) { showEmailFlow = true } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope")
                        .font(.system(size: 15))
                    Text("用 Email 登入")
                        .font(DSText.ui(theme, 15, weight: .medium))
                }
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    /// Step 1 of email flow: collect email, request OTP.
    private var emailEntryFlow: some View {
        VStack(spacing: 12) {
            TextField("you@example.com", text: $emailDraft)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .font(DSText.ui(theme, 16))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: requestOTP) {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("寄個 link 畀我")
                            .font(DSText.ui(theme, 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canRequestOTP ? theme.rose : theme.line)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canRequestOTP || isSubmitting)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showEmailFlow = false }
                emailDraft = ""
            } label: {
                Text("← 返")
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(theme.inkMuted)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    /// Step 2 of email flow: enter the 6-digit OTP from the email.
    private func otpEntryFlow(forEmail email: String) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("已寄個 6 位數字 code 去")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
                Text(email)
                    .font(DSText.mono(theme, 13))
                    .foregroundStyle(theme.ink)
            }
            .padding(.bottom, 4)

            TextField("123456", text: $otpDraft)
                .keyboardType(.numberPad)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(height: 60)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: otpDraft) { _, newValue in
                    otpDraft = String(newValue.filter(\.isNumber).prefix(6))
                }

            Button(action: { Task { await verifyOTP(email: email) } }) {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("確認")
                            .font(DSText.ui(theme, 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canVerify ? theme.rose : theme.line)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canVerify || isSubmitting)

            Button {
                auth.cancelEmailFlow()
                otpDraft = ""
            } label: {
                Text("← 用另一個方法")
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(theme.inkMuted)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var canRequestOTP: Bool {
        let t = emailDraft.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".")
    }

    private var canVerify: Bool { otpDraft.count == 6 }

    // MARK: - Actions

    private func requestOTP() {
        isSubmitting = true
        Task {
            _ = await auth.sendEmailOTP(to: emailDraft)
            isSubmitting = false
        }
    }

    private func verifyOTP(email: String) async {
        guard let p = profileStore.profile else { return }
        isSubmitting = true
        await auth.verifyEmailOTP(email: email, code: otpDraft, profile: p)
        isSubmitting = false
    }
}

#Preview("Sign in") {
    SignInView()
        .environmentObject(UserProfileStore())
        .environmentObject(AuthService())
        .theme(.jbeam)
}
