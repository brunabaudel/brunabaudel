import Foundation

/// Runtime flags shared by app entry, persistence, and privacy services.
enum AppRuntime {
    static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }

    /// CloudKit entitlements are not applied in unsigned simulator CI builds
    /// (`CODE_SIGNING_ALLOWED=NO`). Sync stays enabled on signed device builds.
    static var shouldUseCloudKitSync: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        !isRunningTests
        #endif
    }
}
