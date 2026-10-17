import XCTest
import StoreKit
import UIKit

// Included by the app test targets, but deliberately skipped in normal local tests.
// SubmitDock's iap-probe opts in using a scheme with no .storekit override.
@MainActor final class IAPSandboxTests: XCTestCase {
    func testProductMetadata() async throws {
        guard ProcessInfo.processInfo.environment["SUBMITDOCK_IAP_PROBE"] == "1" else {
            throw XCTSkip("Run the explicit real-device Sandbox probe.")
        }
        #if targetEnvironment(simulator)
        XCTFail("A simulator/local StoreKit result cannot verify Apple's Sandbox catalog.")
        return
        #else
        let input = try XCTUnwrap(ProcessInfo.processInfo.environment["SUBMITDOCK_IAP_EXPECTED"]?.data(using: .utf8))
        let expected = try XCTUnwrap(JSONSerialization.jsonObject(with: input) as? [String: Any])
        let app = try XCTUnwrap(expected["app"] as? [String: String])
        for (key, info) in [("bundleID", "CFBundleIdentifier"), ("version", "CFBundleShortVersionString"), ("build", "CFBundleVersion")] {
            XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: info) as? String, app[key])
        }
        let requests = try XCTUnwrap(expected["purchases"] as? [[String: Any]])
        let ids = try requests.map { try XCTUnwrap($0["productID"] as? String) }
        XCTAssertFalse(ids.isEmpty)
        let currentStorefront = await Storefront.current
        let storefront = try XCTUnwrap(currentStorefront)
        let products = try await Product.products(for: ids)
        var rows: [[String: Any]] = []
        for id in ids {
            let product = try XCTUnwrap(products.first { $0.id == id }, "Sandbox returned no product: \(id)")
            let kind: String
            switch product.type {
            case .nonConsumable: kind = "NON_CONSUMABLE"
            case .consumable: kind = "CONSUMABLE"
            case .nonRenewable: kind = "NON_RENEWING_SUBSCRIPTION"
            case .autoRenewable: kind = "AUTO_RENEWABLE_SUBSCRIPTION"
            default: kind = product.type.rawValue
            }
            rows.append(["productID": id, "type": kind, "fetched": true, "storefront": storefront.countryCode,
                         "price": NSDecimalNumber(decimal: product.price).stringValue,
                         "currency": product.priceFormatStyle.currencyCode])
        }
        let record: [String: Any] = ["schemaVersion": 1, "status": "passed", "testsExecuted": 1,
            // Development-signed app + no Xcode StoreKit override uses Apple's Sandbox.
            // The runner enforces that setup; this probe never requests a purchase/receipt.
            "environment": "Sandbox",
            "physicalDevice": true, "localStoreKitConfiguration": false,
            "testedAt": ISO8601DateFormatter().string(from: Date()),
            "bundleID": app["bundleID"]!, "version": app["version"]!, "build": app["build"]!,
            "osVersion": UIDevice.current.systemVersion, "deviceClass": UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone",
            "products": rows, "purchaseFlow": "NOT_TESTED", "restoreFlow": "NOT_TESTED"]
        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        print("SUBMITDOCK_IAP_EVIDENCE " + String(decoding: data, as: UTF8.self))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "iap-sandbox-evidence.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }
}
