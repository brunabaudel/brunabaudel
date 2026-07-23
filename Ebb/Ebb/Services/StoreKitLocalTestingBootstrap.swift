import Foundation

#if DEBUG
import StoreKitTest
#endif

/// Loads the bundled StoreKit configuration on the simulator when Xcode's scheme
/// reference does not resolve (the usual cause of empty `Product.products`).
enum StoreKitLocalTestingBootstrap {
    #if DEBUG
    private static var session: SKTestSession?
    #endif

    static func activateIfNeeded() {
        #if DEBUG
        guard !AppRuntime.isRunningTests else { return }
        #if targetEnvironment(simulator)
        activateBundledConfigurationIfNeeded()
        #endif
        #endif
    }

    #if DEBUG
    private static func activateBundledConfigurationIfNeeded() {
        guard session == nil else { return }
        guard let url = Bundle.main.url(forResource: "EbbPlus", withExtension: "storekit") else {
            NSLog("Ebb StoreKit: bundled EbbPlus.storekit not found in app bundle")
            return
        }

        do {
            let testSession = try SKTestSession(contentsOf: url)
            testSession.disableDialogs = false
            try testSession.clearTransactions()
            session = testSession
            NSLog("Ebb StoreKit: activated bundled configuration")
        } catch {
            NSLog("Ebb StoreKit: SKTestSession failed: %@", error.localizedDescription)
        }
    }
    #endif
}
