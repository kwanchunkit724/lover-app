import SwiftUI
import UIKit

// v1.6.1 (problem 3) — full-screen, zoomable viewer for a chat photo.
// The decrypted UIImage is already in memory (EncryptedAsyncImage holds it
// from EncryptedImageCache), so this presents instantly with NO re-download
// and NO re-decrypt. Mirrors the FullscreenVideoPlayer precedent used by
// EncryptedVideoPlayback.
struct FullscreenImageViewer: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnification)
                .gesture(scale > 1 ? pan : nil)
                .onTapGesture(count: 2) { toggleZoom() }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        // Swipe down (when not zoomed) dismisses, iOS photo-viewer style.
        .gesture(scale <= 1 ? dismissDrag : nil)
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { resetZoom() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var dismissDrag: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.height > 120 { onDismiss() }
            }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if scale > 1 { resetZoom() } else { scale = 2; lastScale = 2 }
        }
    }

    private func resetZoom() {
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
    }
}
