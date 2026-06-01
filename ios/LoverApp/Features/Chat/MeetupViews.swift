import SwiftUI

// v1.6.1 Feature 6 — meet-up UI: countdown banner, set-date sheet, and the
// "take a selfie" prompt shown when the meet-up day arrives.

/// Countdown pill shown at the top of the chat. Tapping it opens the set sheet
/// (to change/clear) or, when nothing is set, prompts to set one.
struct MeetupBanner: View {
    @Environment(\.theme) private var theme
    let upcoming: Meetup?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text("💕")
                if let m = upcoming {
                    let d = m.daysUntil
                    Text(d <= 0 ? "今日見面！" : "仲有 \(d) 日見面")
                        .font(DSText.ui(theme, 13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("· \(m.title)")
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(1)
                } else {
                    Text("設定下次見面")
                        .font(DSText.ui(theme, 13, weight: .semibold))
                        .foregroundStyle(theme.rose)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(theme.roseSoft)
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
                     alignment: .bottom)
        }
        .buttonStyle(.plain)
    }
}

/// Date + title picker to create the next meet-up.
struct SetMeetupSheet: View {
    @Environment(\.theme) private var theme
    let existing: Meetup?
    let onCreate: (_ dateISO: String, _ title: String) -> Void
    let onCancel: (_ existingId: UUID?) -> Void   // cancel an existing meet-up
    let onClose: () -> Void

    @State private var date = Date()
    @State private var title = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 16) {
                Text("下次幾時見面？")
                    .font(DSText.ui(theme, 17, weight: .semibold))
                    .foregroundStyle(theme.ink)

                DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(theme.rose)

                TextField("做咩？(例如：睇戲、食飯)", text: $title)
                    .font(DSText.ui(theme, 14))
                    .padding(12)
                    .background(theme.paperAlt, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    onCreate(LocalDate.string(from: date), title)
                    onClose()
                } label: {
                    Text("確定")
                        .font(DSText.ui(theme, 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.rose, in: Capsule())
                }
                .buttonStyle(.plain)

                if let existing {
                    Button { onCancel(existing.id); onClose() } label: {
                        Text("取消今次見面")
                            .font(DSText.mono(theme, 12))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24).fill(theme.nav))
            .padding(.horizontal, 20)
        }
    }
}

/// Full-screen prompt shown on the meet-up day until the user submits a selfie.
/// Hosts the camera itself (nested cover) so the caller only presents this one.
struct SelfiePromptView: View {
    @Environment(\.theme) private var theme
    let meetup: Meetup
    let onCapture: (Data) -> Void
    let onLater: () -> Void

    @State private var showCamera = false

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 22) {
                Text("( ´ ▽ ` )ﾉ").font(.system(size: 44)).foregroundStyle(theme.rose)
                Text("今日見面喇！🎉")
                    .font(DSText.ui(theme, 22, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("影張自拍留念，會自動加入紀念冊")
                    .font(DSText.ui(theme, 14))
                    .foregroundStyle(theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Button { showCamera = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("影自拍")
                    }
                    .font(DSText.ui(theme, 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 13)
                    .background(theme.rose, in: Capsule())
                }
                .buttonStyle(.plain)

                Button("遲啲先", action: onLater)
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(theme.inkMuted)
                    .buttonStyle(.plain)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraSheet(
                onPick: { data in showCamera = false; onCapture(data) },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }
}
