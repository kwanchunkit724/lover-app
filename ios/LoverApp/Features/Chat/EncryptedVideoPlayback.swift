import SwiftUI
import AVKit
import AVFoundation

// v1.6.0 — E2EE video bubble. Mirror of EncryptedAudioPlayback but for short
// videos. On bubble render we lazily download + decrypt the encrypted blob,
// write the cleartext bytes to a per-message temp .mp4 in NSTemporaryDirectory,
// then point an AVPlayer at the file URL (AVPlayer can't initialise from raw
// Data — it needs a URL).
//
// Bubble shows: a thumbnail (frame 0) + ▶ overlay + duration tag. Tap →
// presents a fullscreen `VideoPlayer` for playback. The temp file persists
// for the app session; we don't clean up eagerly because the bubble may be
// scrolled in/out and we'd be re-decrypting on every appearance.

struct EncryptedVideoPlayback: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var chat: ChatService

    let messageID: String
    let mediaHandle: String
    let durationSec: Int
    let isFromMe: Bool

    @State private var localURL: URL? = nil
    @State private var thumbnail: UIImage? = nil
    @State private var isLoading = false
    @State private var failed = false
    @State private var showFullscreen = false

    var body: some View {
        Button {
            if localURL != nil {
                showFullscreen = true
            } else {
                Task { await load(presentAfter: true) }
            }
        } label: {
            ZStack {
                // Background — thumbnail once we have it, otherwise the
                // neutral surface so the bubble has a fixed size from the
                // first paint (avoids layout jumping when the thumb arrives).
                Rectangle()
                    .fill(theme.paperAlt)
                    .frame(width: 220, height: 260)

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 260)
                        .clipped()
                }

                // Dim overlay so the play glyph stays legible on bright
                // thumbnails.
                Color.black.opacity(thumbnail == nil ? 0.0 : 0.18)
                    .frame(width: 220, height: 260)

                VStack(spacing: 6) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else if failed {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                }

                // Duration tag — bottom-right.
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(durationLabel)
                            .font(DSText.mono(theme, 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }
            }
            .frame(width: 220, height: 260)
        }
        .buttonStyle(.plain)
        .task {
            // Eagerly decrypt on appear so the thumbnail appears without
            // requiring a tap. If this turns out to chew bandwidth we can
            // gate it behind a tap.
            await load(presentAfter: false)
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            if let url = localURL {
                FullscreenVideoPlayer(url: url) { showFullscreen = false }
            }
        }
    }

    private var durationLabel: String {
        let m = durationSec / 60
        let s = durationSec % 60
        return String(format: "%d:%02d", m, s)
    }

    private func load(presentAfter: Bool) async {
        guard localURL == nil, !isLoading else {
            if presentAfter, localURL != nil { showFullscreen = true }
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await chat.mediaService.downloadAndDecrypt(path: mediaHandle)
            // Stable per-message filename so repeated taps reuse the same
            // file (AVPlayer can keep the URL).
            let safe = messageID.replacingOccurrences(of: "/", with: "_")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("us-chat-\(safe).mp4")
            if !FileManager.default.fileExists(atPath: url.path) {
                try data.write(to: url, options: .atomic)
            }
            localURL = url
            thumbnail = await Self.generateThumbnail(url: url)
            if presentAfter { showFullscreen = true }
        } catch {
            failed = true
        }
    }

    /// Pulls a single frame near t=0.1s using AVAssetImageGenerator. We use
    /// 0.1s instead of 0.0 because some encoders place a black frame at the
    /// very start.
    private static func generateThumbnail(url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 440, height: 520) // 2x retina
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let cg = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CGImage, Error>) in
                gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, error in
                    if let image { cont.resume(returning: image) }
                    else { cont.resume(throwing: error ?? NSError(domain: "thumb", code: -1)) }
                }
            }
            return UIImage(cgImage: cg)
        } catch {
            return nil
        }
    }
}

/// Lightweight fullscreen player wrapper — VideoPlayer + dismiss button.
private struct FullscreenVideoPlayer: View {
    let url: URL
    let onClose: () -> Void

    @State private var player: AVPlayer

    init(url: URL, onClose: @escaping () -> Void) {
        self.url = url
        self.onClose = onClose
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear { player.play() }
                .onDisappear { player.pause() }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 4)
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                }
                Spacer()
            }
        }
    }
}
