import SwiftUI
import UIKit

// SwiftUI async image that downloads encrypted bytes from chat-media,
// decrypts with the chat key, and renders. Used by MessageBubble's photo
// branch in v0.4.3 — replaces the placeholder gray rectangle.
//
// Cache: a process-wide NSCache keyed by mediaHandle keeps decrypted UIImages
// hot across scrolls + tab switches so we're not paying download+AES-GCM
// every time the user re-renders a row.

@MainActor
final class EncryptedImageCache {
    static let shared = EncryptedImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 100         // bounded — older photos evict
        cache.totalCostLimit = 64 * 1024 * 1024   // ~64 MB
    }

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)   // RGBA bytes
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

struct EncryptedAsyncImage: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var chat: ChatService

    let mediaHandle: String
    var maxHeight: CGFloat = 240
    var cornerRadius: CGFloat = 14

    @State private var image: UIImage?
    @State private var failed: Bool = false
    // v1.6.1 (problem 3) — tap a decrypted photo to view it full-screen.
    @State private var showFullscreen = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: maxHeight)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { showFullscreen = true }
            } else if failed {
                placeholder(text: "(相片解密失敗)")
            } else {
                placeholder(text: "正在解密…")
                    .overlay(
                        ProgressView()
                            .tint(theme.inkMuted)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: mediaHandle) { await load() }
        .fullScreenCover(isPresented: $showFullscreen) {
            if let image {
                FullscreenImageViewer(image: image) { showFullscreen = false }
            }
        }
    }

    private func placeholder(text: String) -> some View {
        Rectangle()
            .fill(theme.paperAlt)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay(
                Text(text)
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
            )
    }

    private func load() async {
        if let cached = EncryptedImageCache.shared.get(mediaHandle) {
            self.image = cached
            return
        }
        do {
            let data = try await chat.mediaService.downloadAndDecrypt(path: mediaHandle)
            if let ui = UIImage(data: data) {
                EncryptedImageCache.shared.set(ui, for: mediaHandle)
                self.image = ui
            } else {
                self.failed = true
            }
        } catch {
            self.failed = true
        }
    }
}
