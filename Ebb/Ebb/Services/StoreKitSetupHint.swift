import Foundation

/// User-facing hint when StoreKit products fail to load in local development.
enum StoreKitSetupHint {
    static let productsUnavailableMessage =
        "Subscription plans could not be loaded. Run Ebb from Xcode (⌘R) with the EbbPlus StoreKit configuration enabled in the scheme."

    static let purchaseUnavailableMessage =
        "The App Store purchase sheet needs StoreKit products. Run from Xcode, or set up the products in App Store Connect for device builds."
}
