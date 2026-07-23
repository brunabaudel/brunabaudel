import Foundation
import Testing
@testable import Ebb

@Suite("Ebb+ entitlement evaluator")
struct EbbPlusEntitlementEvaluatorTests {
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    @Test func activeAnnualTrialGrantsAccess() {
        let trialEnd = now.addingTimeInterval(7 * 24 * 60 * 60)
        #expect(
            EbbPlusEntitlementEvaluator.grantsAccess(
                productID: EbbPlusProductIDs.annual,
                revocationDate: nil,
                expirationDate: trialEnd,
                now: now
            )
        )
    }

    @Test func expiredSubscriptionDoesNotGrantAccess() {
        #expect(
            !EbbPlusEntitlementEvaluator.grantsAccess(
                productID: EbbPlusProductIDs.annual,
                revocationDate: nil,
                expirationDate: now.addingTimeInterval(-60),
                now: now
            )
        )
    }

    @Test func lifetimePurchaseGrantsAccess() {
        #expect(
            EbbPlusEntitlementEvaluator.grantsAccess(
                productID: EbbPlusProductIDs.lifetime,
                revocationDate: nil,
                expirationDate: nil,
                now: now
            )
        )
    }

    @Test func unknownProductDoesNotGrantAccess() {
        #expect(
            !EbbPlusEntitlementEvaluator.grantsAccess(
                productID: "com.example.other",
                revocationDate: nil,
                expirationDate: nil,
                now: now
            )
        )
    }
}
