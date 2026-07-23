import Foundation
import StoreKit
import Observation

enum EntitlementError: LocalizedError {
    case productUnavailable

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "The subscription is not available right now. Please try again later."
        }
    }
}

/// Source of truth for the user's plan. Premium is an auto-renewable
/// subscription verified through StoreKit 2 transaction entitlements.
@Observable
@MainActor
final class EntitlementsService {

    static let shared = EntitlementsService()

    /// Auto-renewable subscription product (configure in App Store Connect).
    static let premiumProductID = "com.rymoslite.similitude.premium"

    private(set) var isPremium = false
    private(set) var product: Product?
    private(set) var purchaseInProgress = false

    private var updatesTask: Task<Void, Never>?

    /// Tester toggle so premium flows are verifiable without a purchase.
    /// Honored only in DEBUG and TestFlight builds — App Store builds
    /// ignore the stored value entirely.
    var testingPremiumOverride: Bool {
        get { UserDefaults.standard.bool(forKey: "debug.premiumOverride") }
        set {
            UserDefaults.standard.set(newValue, forKey: "debug.premiumOverride")
            Task { await refreshEntitlement() }
        }
    }

    private init() {
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlement()
            }
        }
        Task {
            await refreshEntitlement()
            await loadProduct()
        }
    }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.premiumProductID]).first
    }

    func purchase() async throws {
        if product == nil { await loadProduct() }
        guard let product else { throw EntitlementError.productUnavailable }
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let result = try await product.purchase()
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
        }
        await refreshEntitlement()
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        if BuildEnvironment.isTestBuild,
           UserDefaults.standard.bool(forKey: "debug.premiumOverride") {
            isPremium = true
            return
        }

        var premium = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.premiumProductID,
               transaction.revocationDate == nil {
                premium = true
            }
        }
        isPremium = premium
    }
}
