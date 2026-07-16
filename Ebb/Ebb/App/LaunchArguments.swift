import Foundation

/// Launch arguments read by views during CI screenshot capture (`ci/capture_screenshots.sh`).
enum LaunchArguments {
    static let autoTapLog = "-AutoTapLog"
    static let autoTalkLog = "-AutoTalkLog"
    static let autoConfirmLog = "-AutoConfirmLog"
    static let openTabCalendar = "-OpenTabCalendar"
    static let mockTranscript = "-MockTranscript"
}

extension ProcessInfo {
    var hasLaunchArgumentAutoTapLog: Bool {
        arguments.contains(LaunchArguments.autoTapLog)
    }

    var hasLaunchArgumentAutoTalkLog: Bool {
        arguments.contains(LaunchArguments.autoTalkLog)
    }

    var hasLaunchArgumentAutoConfirmLog: Bool {
        arguments.contains(LaunchArguments.autoConfirmLog)
    }

    var hasLaunchArgumentOpenTabCalendar: Bool {
        arguments.contains(LaunchArguments.openTabCalendar)
    }

    /// Canned transcript for CI screenshots and simulator runs (follows `-MockTranscript`).
    var mockTranscriptText: String? {
        guard let index = arguments.firstIndex(of: LaunchArguments.mockTranscript),
              index + 1 < arguments.count else {
            return nil
        }
        let text = arguments[index + 1]
        return text.isEmpty ? nil : text
    }
}
