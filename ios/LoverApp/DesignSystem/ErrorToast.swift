import SwiftUI

// v1.4.1 — pinned bottom error banner for surfacing service-level
// lastError values (EntryService / PlayHistoryService / ChatService /
// PairingService). Before this, async errors set lastError and the view
// silently absorbed them, so users couldn't screenshot what went wrong
// when filing a bug report. Use:
//
//     .errorToast($entries.lastError)
//
// Tapping the banner dismisses it (sets the binding to nil).

struct ErrorToast: ViewModifier {
    @Binding var message: String?
    @Environment(\.theme) private var theme

    /// Hide task-cancellation noise (a fetch cancelled on view teardown /
    /// service restart surfaces as "Swift.CancellationError error 1" — not a
    /// real failure the user should see).
    private var visibleMessage: String? {
        guard let m = message else { return nil }
        let low = m.lowercased()
        if m.contains("CancellationError") || low.contains("cancel") || low.contains("error 1") {
            return nil
        }
        return m
    }

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = visibleMessage {
                Button { message = nil } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("出咗 bug — tap 關閉")
                                .font(DSText.mono(theme, 10).weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(msg)
                                .font(DSText.ui(theme, 12))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: message)
    }
}

extension View {
    /// Pin a bottom error banner that shows whenever `message` is non-nil.
    /// Tapping the banner clears it.
    func errorToast(_ message: Binding<String?>) -> some View {
        modifier(ErrorToast(message: message))
    }
}
