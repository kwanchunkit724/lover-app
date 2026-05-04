import Foundation
import AVFoundation
import Combine

// AVAudioRecorder wrapper for voice messages. Records to a temp .m4a file
// (AAC, mono, 22.05 kHz) — small enough for unencrypted+encrypted transit
// to stay under a couple hundred KB for typical 5–30s clips.
//
// Lifecycle:
//   start() → permission prompt on first call, then begins recording.
//   stop()  → returns the audio Data + duration. Tempfile auto-cleaned.

@MainActor
final class AudioRecorder: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var seconds: Int = 0
    @Published var lastError: String?

    private var recorder: AVAudioRecorder?
    private var tempURL: URL?
    private var tickTask: Task<Void, Never>?

    /// Begins recording. Async — awaits microphone permission first.
    /// Returns true on success, false if permission denied or setup failed.
    func start() async -> Bool {
        guard !isRecording else { return false }

        // Permission gate.
        let granted = await requestMicPermission()
        guard granted else {
            lastError = "需要授權麥克風先可以錄音"
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("us-voice-\(UUID().uuidString).m4a")
            self.tempURL = url

            let settings: [String: Any] = [
                AVFormatIDKey:          kAudioFormatMPEG4AAC,
                AVSampleRateKey:        22050,
                AVNumberOfChannelsKey:  1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            guard r.record() else {
                lastError = "錄音失敗"
                return false
            }
            self.recorder = r
            self.isRecording = true
            self.seconds = 0
            startTicking()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Stops recording, returns (audioData, duration in seconds). Returns
    /// nil if nothing was recorded or read failed.
    func stop() -> (data: Data, durationSec: Int)? {
        guard isRecording, let recorder, let url = tempURL else { return nil }
        let duration = max(1, Int(recorder.currentTime.rounded()))
        recorder.stop()
        self.recorder = nil
        self.isRecording = false
        tickTask?.cancel(); tickTask = nil

        defer {
            // Clean up the temp file regardless of read result.
            try? FileManager.default.removeItem(at: url)
            self.tempURL = nil
            try? AVAudioSession.sharedInstance().setActive(false)
        }

        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return nil
        }
        return (data, duration)
    }

    /// Cancel without producing data.
    func cancel() {
        guard isRecording else { return }
        recorder?.stop()
        recorder = nil
        isRecording = false
        tickTask?.cancel(); tickTask = nil
        if let url = tempURL { try? FileManager.default.removeItem(at: url) }
        tempURL = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Helpers

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                await MainActor.run { self?.seconds += 1 }
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            if #available(iOS 17, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }
}
