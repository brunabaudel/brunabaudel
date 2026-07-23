import Foundation

/// App Store product identifiers for Ebb+ (build-plan Phase 10).
enum EbbPlusProductIDs {
    static let monthly = "com.bcbs.ebb.plus.monthly"
    static let annual = "com.bcbs.ebb.plus.annual"
    static let lifetime = "com.bcbs.ebb.plus.lifetime"

    static let all: Set<String> = [monthly, annual, lifetime]
    static let subscriptionIDs: Set<String> = [monthly, annual]
}
