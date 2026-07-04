import Foundation

/// Launch arguments read by views during CI screenshot capture (`ci/capture_screenshots.sh`).
enum LaunchArguments {
    static let autoTapLog = "-AutoTapLog"
    static let openTabCalendar = "-OpenTabCalendar"
}

extension ProcessInfo {
    var hasLaunchArgumentAutoTapLog: Bool {
        arguments.contains(LaunchArguments.autoTapLog)
    }

    var hasLaunchArgumentOpenTabCalendar: Bool {
        arguments.contains(LaunchArguments.openTabCalendar)
    }
}
