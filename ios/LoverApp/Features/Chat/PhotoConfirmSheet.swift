import SwiftUI
import UIKit

// v1.0.5 — preview + confirm step between photo pick and send. Before this,
// picking from album / shooting in camera immediately fired chat.sendPhoto
// with no chance to back out, which led to accidental sends.
//
// Used as a sheet by ChatView; the parent owns the buffered Data.

struct PhotoPreviewItem: Identifiable {
    let id = UUID()
    let data: Data
}

struct PhotoConfirmSheet: View {
    @Environment(\.theme) private var theme
    let imageData: Data
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView {
                if let ui = UIImage(data: imageData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                } else {
                    Text("圖片讀唔到")
                        .font(DSText.ui(theme, 14))
                        .foregroundStyle(theme.inkMuted)
                        .padding(40)
                }
            }

            sendBar
        }
        .background(theme.paper.ignoresSafeArea())
    }

    private var navBar: some View {
        HStack {
            Button { onCancel() } label: {
                DSIcon(name: .close, size: 22, color: theme.rose, strokeWidth: 2.2)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("send 出去？")
                .font(DSText.ui(theme, 16, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Color.clear.frame(width: 30, height: 30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var sendBar: some View {
        Button(action: onSend) {
            HStack(spacing: 6) {
                DSIcon(name: .arrow, size: 16, color: .white, strokeWidth: 2.4)
                Text("Send")
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.rose)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }
}
