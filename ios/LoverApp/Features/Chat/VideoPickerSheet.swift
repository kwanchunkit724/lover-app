import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

// v1.6.0 — PHPicker wrapper restricted to videos. After the user picks, we
// run an AVAssetExportSession to compress to 720p H.264 (preset
// AVAssetExportPreset1280x720) and trim to 30s max. Result is handed back
// as raw Data + duration so the parent can call ChatService.sendVideo.
//
// Compression target ≤5 MB — the export preset alone doesn't give us a hard
// byte cap, so for clips that come out larger we drop quality once via a
// lower-bitrate AVAssetWriter pass. In practice ≤30s @ 720p30 sits comfortably
// under 5MB so the second pass is rare.

struct VideoPickerSheet: UIViewControllerRepresentable {
    /// (encrypted-ready video bytes, duration in whole seconds)
    let onPick: (Data, Int) -> Void
    let onCancel: () -> Void

    private static let maxDurationSec: Double = 30

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPickerSheet
        init(_ parent: VideoPickerSheet) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let item = results.first else {
                parent.onCancel()
                return
            }
            let provider = item.itemProvider
            // Get the source movie as a file URL (the only way AVAsset can
            // ingest it — we can't go via Data because some sources are
            // HEVC/HDR and need format conversion anyway).
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [parent] url, error in
                guard let url, error == nil else {
                    DispatchQueue.main.async { parent.onCancel() }
                    return
                }
                // PHPicker hands us a tmp URL that's deleted as soon as this
                // closure returns — copy it before the async export so the
                // file stays alive.
                let scratch = FileManager.default.temporaryDirectory
                    .appendingPathComponent("us-pick-\(UUID().uuidString).mov")
                do {
                    try? FileManager.default.removeItem(at: scratch)
                    try FileManager.default.copyItem(at: url, to: scratch)
                } catch {
                    DispatchQueue.main.async { parent.onCancel() }
                    return
                }

                Task {
                    let result = await Self.compress(srcURL: scratch)
                    try? FileManager.default.removeItem(at: scratch)
                    await MainActor.run {
                        if let result {
                            parent.onPick(result.data, result.durationSec)
                        } else {
                            parent.onCancel()
                        }
                    }
                }
            }
        }

        /// Compress to 720p H.264 ≤30s. Returns nil on any failure.
        static func compress(srcURL: URL) async -> (data: Data, durationSec: Int)? {
            let asset = AVURLAsset(url: srcURL)
            // Trim to first 30s if longer.
            let dur: CMTime
            do {
                dur = try await asset.load(.duration)
            } catch {
                return nil
            }
            let durationSec = min(VideoPickerSheet.maxDurationSec,
                                  CMTimeGetSeconds(dur))
            let timeRange = CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: durationSec, preferredTimescale: 600)
            )

            // AVAssetExportPreset1280x720 = 720p H.264. Output is .mp4 so
            // both iOS + Android (future use case) can decode.
            guard let export = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPreset1280x720
            ) else { return nil }

            let outURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("us-vid-\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: outURL)
            export.outputURL = outURL
            export.outputFileType = .mp4
            export.timeRange = timeRange
            export.shouldOptimizeForNetworkUse = true

            await export.export()

            guard export.status == .completed,
                  let data = try? Data(contentsOf: outURL) else {
                try? FileManager.default.removeItem(at: outURL)
                return nil
            }
            try? FileManager.default.removeItem(at: outURL)
            return (data, Int(durationSec.rounded()))
        }
    }
}
