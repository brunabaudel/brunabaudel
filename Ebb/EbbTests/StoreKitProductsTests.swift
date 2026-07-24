import StoreKit
import StoreKitTest
import Testing
@testable import Ebb

@Suite("StoreKit products", .serialized)
struct StoreKitProductsTests {
    private static let fallbackConfigURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("EbbPlus.storekit")

    private static var configURL: URL {
        Bundle.main.url(forResource: "EbbPlus", withExtension: "storekit") ?? fallbackConfigURL
    }

    private static var session: SKTestSession?

    init() throws {
        if Self.session == nil {
            let session = try SKTestSession(contentsOf: Self.configURL)
            session.disableDialogs = true
            try session.clearTransactions()
            Self.session = session
        }
    }

    @Test func configurationFileExists() {
        #expect(FileManager.default.fileExists(atPath: Self.configURL.path))
    }

    @Test func loadsAllEbbPlusProducts() async throws {
        let session = try #require(Self.session)
        try session.clearTransactions()

        var products: [Product] = []
        for _ in 0..<6 {
            products = try await Product.products(for: Array(EbbPlusProductIDs.all))
            if products.count == EbbPlusProductIDs.all.count { break }
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        #expect(products.count == EbbPlusProductIDs.all.count)
    }
}
