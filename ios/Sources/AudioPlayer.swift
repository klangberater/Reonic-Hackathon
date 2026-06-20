import AVFoundation

/// Plays the ElevenLabs mp3 verdict ("All done on sunshine — €0.40 instead of €3.10").
/// Best-effort: a failed playback never breaks the plan reveal.
final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()
    private var player: AVAudioPlayer?

    func play(_ data: Data) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let p = try AVAudioPlayer(data: data)
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            // best-effort — the on-screen money reveal stands on its own
        }
    }
}
