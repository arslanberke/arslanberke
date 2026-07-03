import StoreKit
import SwiftUI

/// StoreKit 2 integration: remove-ads purchase and cosmetic theme packs.
/// No pay-to-win items — everything gameplay-related is earnable with coins.
@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    enum ProductID {
        static let removeAds = "com.shapesnap.iap.removeads"
        static let themePackNature = "com.shapesnap.iap.themes.nature"
        static let themePackNight = "com.shapesnap.iap.themes.night"
        static let all = [removeAds, themePackNature, themePackNight]
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactions() }
        Task { await loadProducts(); await refreshPurchases() }
    }

    func loadProducts() async {
        products = (try? await Product.products(for: ProductID.all)) ?? []
    }

    func purchase(_ product: Product) async {
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result, case .verified(let transaction) = verification {
            apply(transaction)
            await transaction.finish()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshPurchases()
    }

    private func refreshPurchases() async {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement { apply(transaction) }
        }
    }

    private func listenForTransactions() async {
        for await update in StoreKit.Transaction.updates {
            if case .verified(let transaction) = update {
                apply(transaction)
                await transaction.finish()
            }
        }
    }

    private func apply(_ transaction: StoreKit.Transaction) {
        purchasedIDs.insert(transaction.productID)
        switch transaction.productID {
        case ProductID.removeAds:
            PlayerProgress.shared.removeAdsPurchased = true
        case ProductID.themePackNature:
            PlayerProgress.shared.unlockedThemes.formUnion(["forest", "sunset"])
        case ProductID.themePackNight:
            PlayerProgress.shared.unlockedThemes.formUnion(["neon", "mono", "gold"])
        default: break
        }
    }
}

/// Rewarded-ads abstraction. Ships as a no-op stub; wire an ad SDK behind this
/// interface without touching game code. Always optional, never forced.
final class AdsService {
    static let shared = AdsService()

    var adsRemoved: Bool { PlayerProgress.shared.removeAdsPurchased }

    /// Presents a rewarded ad and calls back with success. Stubbed to succeed
    /// immediately so the reward flow is fully testable without an SDK.
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
}
