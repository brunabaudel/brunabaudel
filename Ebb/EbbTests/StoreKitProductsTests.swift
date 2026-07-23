import StoreKit
import StoreKitTest
import Testing
@testable import Ebb

@Suite("StoreKit products", .serialized)
struct StoreKitProductsTests {
    private static let configURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("EbbPlus.storekit")

    private static var session: SKTestSession?

    init() throws {
        if Self.session == nil {
            Self.session = try SKTestSession(contentsOf: Self.configURL)
        }
    }

    @Test func configurationFileExists() {
        #expect(FileManager.default.fileExists(atPath: Self.configURL.path))
    }

    @Test func loadsAllEbbPlusProducts() async throws {
        let products = try await Product.products(for: Array(EbbPlusProductIDs.all))
        #expect(products.count == 3)
    }
}
