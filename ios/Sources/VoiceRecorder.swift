import AVFoundation
import SwiftUI

/// Records the presenter's spoken plan to a short m4a clip for ElevenLabs STT.
/// Exposes a live `level` (0…1) so the mic button can pulse while listening.
@MainActor final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var level: CGFloat = 0

    private var recorder: AVAudioRecorder?
    private var url: URL?
    private var meterTimer: Timer?

    let mime = "audio/m4a"

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let dst = FileManager.default.temporaryDirectory.appendingPathComponent("lumen-voice.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let rec = try AVAudioRecorder(url: dst, settings: settings)
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec
        url = dst
        isRecording = true
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateLevel() }
        }
    }

    /// Stops recording and returns the encoded clip (nil if nothing was captured).
    func stop() -> Data? {
        meterTimer?.invalidate(); meterTimer = nil
        recorder?.stop()
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        defer { recorder = nil }
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }

    private func updateLevel() {
        guard let rec = recorder else { return }
        rec.updateMeters()
        let db = rec.averagePower(forChannel: 0)          // -160…0 dBFS
        level = CGFloat(min(1, max(0, (db + 50) / 50)))   // rough, lively 0…1
    }
}
