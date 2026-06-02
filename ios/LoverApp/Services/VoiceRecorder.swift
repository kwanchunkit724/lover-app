import Foundation
import AVFoundation
import Combine

// v1.6.5 — voice message recorder (re-added; the old one was deleted when
// video send shipped). Records AAC/m4a to a temp file; stop() returns the
// encoded bytes + duration, ready for ChatService.sendVoice (E2EE upload).
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed = 0          // seconds
    @Published private(set) var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var url: URL?
    private var ticker: Task<Void, Never>?

    /// Request mic permission (first time shows the OS prompt), then begin.
    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted { self.begin() } else { self.permissionDenied = true }
            }
        }
    }

    private func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        guard let rec = try? AVAudioRecorder(url: u, settings: settings) else { return }
        rec.record()
        recorder = rec
        url = u
        elapsed = 0
        isRecording = true
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.isRecording else { break }
                self.elapsed += 1
                if self.elapsed >= 120 { _ = self.finish() }   // 2-min cap
            }
        }
    }

    /// Stop + return (data, durationSec). nil if too short / failed.
    func finish() -> (Data, Int)? {
        guard isRecording else { return nil }
        recorder?.stop()
        ticker?.cancel(); ticker = nil
        isRecording = false
        let dur = max(1, elapsed)
        defer { cleanup() }
        guard let u = url, let data = try? Data(contentsOf: u), dur >= 1 else { return nil }
        return (data, dur)
    }

    func cancel() {
        recorder?.stop()
        ticker?.cancel(); ticker = nil
        isRecording = false
        cleanup()
    }

    private func cleanup() {
        if let u = url { try? FileManager.default.removeItem(at: u) }
        recorder = nil
        url = nil
        elapsed = 0
    }
}
