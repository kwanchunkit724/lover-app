import SwiftUI
import PhotosUI

// Phase 4c — wraps the system PHPickerViewController in a SwiftUI sheet.
// One-shot single-photo pick, then the parent calls ChatService.sendPhoto.

struct PhotoPickerSheet: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerSheet
        init(_ parent: PhotoPickerSheet) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let item = results.first else {
                parent.onCancel()
                return
            }
            let provider = item.itemProvider
            // JPEG is fine for transport; downsample if huge to keep encrypt
            // + upload manageable on cellular.
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { [parent] data, _ in
                guard let data else {
                    DispatchQueue.main.async { parent.onCancel() }
                    return
                }
                let downsampled = Self.downsample(data, maxLongEdge: 2048) ?? data
                DispatchQueue.main.async { parent.onPick(downsampled) }
            }
        }

        /// Downscale to a sensible long-edge so chat-media bucket cost stays
        /// bounded — full-res HEIC photos can be 10MB+. JPEG @ 0.8 quality.
        private static func downsample(_ data: Data, maxLongEdge: CGFloat) -> Data? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxLongEdge,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            let ui = UIImage(cgImage: cg)
            return ui.jpegData(compressionQuality: 0.8)
        }
    }
}
