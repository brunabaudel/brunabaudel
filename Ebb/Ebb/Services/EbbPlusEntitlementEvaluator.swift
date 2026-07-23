import Foundation

/// Pure entitlement checks shared by purchase handling and StoreKit refresh.
enum EbbPlusEntitlementEvaluator {
    static func grantsAccess(
        productID: String,
        revocationDate: Date?,
        expirationDate: Date?,
        now: Date = .now
    ) -> Bool {
        guard EbbPlusProductIDs.all.contains(productID) else { return false }
        guard revocationDate == nil else { return false }
        if let expirationDate, expirationDate <= now {
            return false
        }
        return true
    }
}
