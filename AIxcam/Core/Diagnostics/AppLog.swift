import Foundation
import OSLog

/// Shared `os.Logger` instances, one per area of the app.
///
/// Replaces `print("[Tag] …")`. Those never reach Console.app or a sysdiagnose
/// pulled from a real device, they carry no severity, and they stay compiled
/// into release builds — where the ones that interpolated response bodies and
/// user IDs were handing that data to anyone with a cable.
///
/// Interpolated values are redacted in release builds by default. Mark a value
/// `privacy: .public` only when it is genuinely not user data (a status code,
/// an enum case). Never log tokens, ID numbers, or response bodies.
nonisolated enum AppLog {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.aixcam.AIxcam"

    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let camera = Logger(subsystem: subsystem, category: "camera")
    static let payments = Logger(subsystem: subsystem, category: "payments")
    static let profile = Logger(subsystem: subsystem, category: "profile")
    static let streaming = Logger(subsystem: subsystem, category: "streaming")
}
