import Foundation
import Observation
import StoreKit

enum EntitlementsError: LocalizedError, Equatable {
    case productNotFound
    case purchasePending
    case userCancelled
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            "That plan is not available right now. Try again in a moment."
        case .purchasePending:
            "Your purchase is pending approval."
        case .userCancelled:
            nil
        case .verificationFailed:
            "Could not verify your purchase. Try Restore purchases."
        }
    }
}

/// StoreKit 2 subscription state — single gate point for every Ebb+ check.
@Observable
@MainActor
final class EntitlementsService {
    private(set) var isEbbPlus = false
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var lastErrorMessage: String?

    private(set) var monthlyProduct: Product?
    private(set) var annualProduct: Product?
    private(set) var lifetimeProduct: Product?
    private(set) var productsDidLoad = false

    var hasLoadedProducts: Bool {
        monthlyProduct != nil || annualProduct != nil || lifetimeProduct != nil
    }

    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    init(previewIsEbbPlus: Bool = false, listenForUpdates: Bool = true) {
        isEbbPlus = previewIsEbbPlus
        guard listenForUpdates else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.refreshEntitlements(including: transaction)
                    await transaction.finish()
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func bootstrap() async {
        await loadProducts(retryCount: 3)
        await refreshEntitlements()
    }

    func loadProducts(retryCount: Int = 1) async {
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            productsDidLoad = true
        }

        for attempt in 0..<retryCount {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(400 * attempt))
            }

            if await fetchProducts() {
                return
            }
        }
    }

    @discardableResult
    private func fetchProducts() async -> Bool {
        do {
            let products = try await Product.products(for: Array(EbbPlusProductIDs.all))
            monthlyProduct = products.first { $0.id == EbbPlusProductIDs.monthly }
            annualProduct = products.first { $0.id == EbbPlusProductIDs.annual }
            lifetimeProduct = products.first { $0.id == EbbPlusProductIDs.lifetime }

            #if DEBUG
            print(
                "Ebb StoreKit: loaded \(products.count) products →",
                products.map(\.id).joined(separator: ", ")
            )
            #endif

            if products.isEmpty {
                lastErrorMessage = StoreKitSetupHint.productsUnavailableMessage
                return false
            }

            if !hasLoadedProducts {
                lastErrorMessage = "Some Ebb+ plans could not be loaded. Try again."
                return false
            }

            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            #if DEBUG
            print("Ebb StoreKit: Product.products failed →", error.localizedDescription)
            #endif
            return false
        }
    }

    func refreshEntitlements(including transaction: Transaction? = nil) async {
        var hasAccess = false

        if let transaction, Self.grantsEbbPlus(transaction) {
            hasAccess = true
        }

        if !hasAccess {
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                if Self.grantsEbbPlus(transaction) {
                    hasAccess = true
                    break
                }
            }
        }

        isEbbPlus = hasAccess
    }

    func purchase(_ product: Product) async throws {
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw EntitlementsError.verificationFailed
            }
            await transaction.finish()
            await refreshEntitlements(including: transaction)

            if !isEbbPlus {
                // Intro-offer annual subscriptions can lag in `currentEntitlements`.
                for delay in [200, 400, 800] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    await refreshEntitlements(including: transaction)
                    if isEbbPlus { break }
                }
            }
        case .userCancelled:
            throw EntitlementsError.userCancelled
        case .pending:
            throw EntitlementsError.purchasePending
        @unknown default:
            throw EntitlementsError.verificationFailed
        }
    }

    func restorePurchases() async throws {
        lastErrorMessage = nil
        try await AppStore.sync()
        await refreshEntitlements()
        guard isEbbPlus else {
            lastErrorMessage = "No active Ebb+ subscription was found for this Apple ID."
            return
        }
    }

    private static func grantsEbbPlus(_ transaction: Transaction) -> Bool {
        EbbPlusEntitlementEvaluator.grantsAccess(
            productID: transaction.productID,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate
        )
    }
}
