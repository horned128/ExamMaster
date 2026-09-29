import Foundation
import Observation
import StoreKit

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
    private(set) var purchasing = false
    var error: String?
    let productID: String
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(productID: String) {
        self.productID = productID
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result { await transaction.finish() }
                await self.refreshEntitlement()
            }
        }
        Task { await refresh() }
    }

    deinit { updates?.cancel() }

    func refresh() async {
        await refreshEntitlement()
        do {
            product = try await Product.products(for: [productID]).first { $0.id == productID && $0.type == .nonConsumable }
            if product == nil { error = "商品情報を取得できません。通信状態と商品設定をご確認ください。" }
        } catch {
            self.error = "商品情報を取得できません。通信状態を確認して再試行してください。"
        }
        loading = false
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
        if unlocked { error = nil }
    }

    func buy() async {
        guard let product, !purchasing else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
            case .success(.unverified):
                error = "購入を確認できませんでした。購入を復元して再確認してください。"
            case .pending:
                error = "購入は承認待ちです。承認後に自動で反映されます。"
            case .userCancelled: break
            @unknown default: break
            }
        } catch { self.error = "購入に失敗しました: \(error.localizedDescription)" }
    }

    func restore() async {
        purchasing = true
        defer { purchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !unlocked { error = "復元できる購入が見つかりませんでした。購入時のApple Accountをご確認ください。" }
        } catch { self.error = "復元に失敗しました: \(error.localizedDescription)" }
    }
}
