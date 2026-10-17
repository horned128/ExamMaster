import Foundation
import Observation
import StoreKit
import OSLog

enum ProductLoadFailure: Equatable {
    case unavailable
    case storeError(domain: String, code: Int)
}

struct PurchaseEntitlement {
    let productID: String
    let verified: Bool
    let revoked: Bool
    let nonConsumable: Bool
}

enum PurchasePolicy {
    static func isUnlocked(productID: String, entitlements: [PurchaseEntitlement]) -> Bool {
        entitlements.contains {
            $0.productID == productID && $0.verified && !$0.revoked && $0.nonConsumable
        }
    }
}

@MainActor @Observable final class PurchaseManager {
    private(set) var unlocked = false
    private(set) var product: Product?
    private(set) var loading = true
    private(set) var entitlementResolved = false
    private(set) var purchasing = false
    private var productError: String?
    private var operationError: String?
    var error: String? { operationError ?? (unlocked ? nil : productError) }
    private(set) var productLoadFailure: ProductLoadFailure?
    private(set) var storefrontCountryCode: String?
    let productID: String
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var storefrontUpdates: Task<Void, Never>?
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ExamMaster", category: "Purchases")

    init(productID: String) {
        self.productID = productID
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result { await transaction.finish() }
                await self.refreshEntitlement()
            }
        }
        storefrontUpdates = Task { [weak self] in
            for await _ in Storefront.updates {
                guard let self else { return }
                await self.refreshForStorefrontChange()
            }
        }
        Task { await refresh() }
    }

    deinit {
        updates?.cancel()
        storefrontUpdates?.cancel()
    }

    func refreshIfNeeded() async {
        await refreshEntitlement()
        if product == nil && !unlocked && !purchasing { await refresh() }
    }

    func refreshForStorefrontChange() async {
        // A request already running may have started against the old storefront.
        // Let it finish, then make a fresh request instead of coalescing with it.
        product = nil
        if let refreshTask { await refreshTask.value }
        product = nil
        await refresh()
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        loading = true
        productError = nil
        productLoadFailure = nil
        let task = Task {
            defer { self.refreshTask = nil }
            await self.loadProductAndEntitlement()
        }
        refreshTask = task
        await task.value
    }

    private func loadProductAndEntitlement() async {
        defer { loading = false }
        await refreshEntitlement()
        storefrontCountryCode = await Storefront.current?.countryCode
        // A transient StoreKit failure must not persist for the whole app session.
        // Bounded retries also cover an empty response, without inventing a price.
        for attempt in 0..<3 {
            do {
                let products = try await Product.products(for: [productID])
                Self.logger.info("Product lookup id=\(self.productID, privacy: .public) storefront=\(self.storefrontCountryCode ?? "unknown", privacy: .public) attempt=\(attempt + 1) count=\(products.count)")
                if let available = products.first(where: { $0.id == productID && $0.type == .nonConsumable }) {
                    product = available
                    productError = nil
                    productLoadFailure = nil
                    return
                }
                productLoadFailure = .unavailable
            } catch is CancellationError {
                return
            } catch {
                let storeError = error as NSError
                productLoadFailure = .storeError(domain: storeError.domain, code: storeError.code)
                Self.logger.error("Product lookup failed id=\(self.productID, privacy: .public) storefront=\(self.storefrontCountryCode ?? "unknown", privacy: .public) domain=\(storeError.domain, privacy: .public) code=\(storeError.code)")
            }
            if attempt < 2 {
                do { try await Task.sleep(for: .milliseconds(500 * (attempt + 1))) }
                catch { return }
            }
        }
        product = nil
        if !unlocked {
            productError = "購入情報を読み込めませんでした。時間をおいて再試行してください。無料の問題は引き続き利用できます。"
        }
    }

    func refreshEntitlement() async {
        var entitlements: [PurchaseEntitlement] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                entitlements.append(PurchaseEntitlement(productID: transaction.productID, verified: true,
                                                        revoked: transaction.revocationDate != nil,
                                                        nonConsumable: transaction.productType == .nonConsumable))
            }
        }
        unlocked = PurchasePolicy.isUnlocked(productID: productID, entitlements: entitlements)
        entitlementResolved = true
        if unlocked { operationError = nil }
    }

    func buy() async {
        guard let product, !purchasing else { return }
        purchasing = true
        operationError = nil
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
            case .success(.unverified):
                operationError = "購入を確認できませんでした。購入を復元して再確認してください。"
            case .pending:
                operationError = "購入は承認待ちです。承認後に自動で反映されます。"
            case .userCancelled: break
            @unknown default: break
            }
        } catch { operationError = "購入に失敗しました: \(error.localizedDescription)" }
    }

    func restore() async {
        purchasing = true
        operationError = nil
        defer { purchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !unlocked { operationError = "復元できる購入が見つかりませんでした。購入時のApple Accountをご確認ください。" }
        } catch { operationError = "復元に失敗しました: \(error.localizedDescription)" }
    }
}
