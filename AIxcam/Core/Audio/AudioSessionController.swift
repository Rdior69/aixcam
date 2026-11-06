import AVFoundation
import OSLog

/// Owns the process-wide `AVAudioSession` category.
///
/// There is exactly one audio session per process, and two screens want
/// different things from it: the broadcaster needs to record, the viewer needs
/// to play. Leaving whichever ran last in charge produced a real bug — going
/// live once left the session in `.playAndRecord` for the rest of the launch,
/// so a stream watched afterwards sounded different from the same stream
/// watched on a fresh start.
///
/// Both call sites go through here, and both release the session when they are
/// done, so the category is always set by the screen currently using it.
nonisolated enum AudioSessionController {

    /// Capture + monitoring for a live broadcast.
    ///
    /// Throws so the broadcaster can be told their stream may be silent —
    /// unlike playback, a broadcast with no audio is worth interrupting for.
    static func activateForBroadcast() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .videoRecording,
            options: [.allowBluetoothHFP, .defaultToSpeaker]
        )
        try session.setActive(true)
    }

    /// Playback for watching a stream.
    ///
    /// `.playback` is the category that ignores the ring/silent switch and
    /// keeps going when the screen locks. The default (`.soloAmbient`) does
    /// neither, which reads as "the app has no sound" to anyone whose phone is
    /// on silent — which is most people, most of the time.
    ///
    /// Best-effort: a viewer whose session won't configure should still get
    /// video rather than an error sheet, so this logs instead of throwing.
    static func activateForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            AppLog.streaming.error(
                "playback audio session failed: \(String(reflecting: error), privacy: .public)"
            )
        }
    }

    /// Hands the session back so whatever was playing before this app can
    /// resume, and so the next screen starts from a clean category.
    static func deactivate() {
        do {
            try AVAudioSession.sharedInstance()
                .setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Deactivation fails routinely and harmlessly — most often because
            // audio is still winding down. The next activation sets the
            // category it needs regardless, so there is nothing to recover.
            AppLog.streaming.notice(
                "audio session deactivate failed: \(String(reflecting: error), privacy: .public)"
            )
        }
    }
}
