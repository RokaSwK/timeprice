import Foundation
import SafariServices
import os.log

/// Receives `browser.runtime.sendNativeMessage` calls from `safari-background.js`.
///
/// Messages:
/// - `{ type: "price-seen", title, host, original, amount, currency, euros }`
///   → stored in the shared price history and broadcast to the notch app.
/// - `{ type: "get-settings" }` → replies with the shared settings.
/// - `{ type: "set-settings", salary, mode, enabled, updatedAt }` → saved and
///   broadcast so the app follows changes made in the extension popup.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let store = SharedStore()
    private let log = Logger(subsystem: "com.rokaswk.timeprice.extension", category: "native")

    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey] as? [String: Any] ?? [:]
        let reply = handle(message)
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: reply]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    func handle(_ message: [String: Any]) -> [String: Any] {
        switch message["type"] as? String {
        case "price-seen":
            guard let title = message["title"] as? String,
                  let euros = message["euros"] as? Double, euros.isFinite, euros >= 0
            else { return ["ok": false] }
            let event = PriceEvent(
                title: String(title.prefix(120)),
                host: String((message["host"] as? String ?? "").prefix(80)),
                original: String((message["original"] as? String ?? "").prefix(40)),
                amount: message["amount"] as? Double ?? euros,
                currency: message["currency"] as? String ?? "EUR",
                euros: euros
            )
            store.update { $0.record(event) }
            Bridge.post(Bridge.priceSeen, event)
            log.debug("price seen on \(event.host, privacy: .public)")
            return ["ok": true]
        case "get-settings":
            return ["ok": true, "settings": payload(store.load().settings)]
        case "set-settings":
            let state = store.update { state in
                let updatedAt = message["updatedAt"] as? Double ?? Date().timeIntervalSince1970
                guard updatedAt >= state.settings.updatedAt else { return }
                if let salary = message["salary"] as? Double, SalaryModel.isValid(salary) {
                    state.settings.salary = salary
                }
                if let mode = (message["mode"] as? String).flatMap(TimeMode.init(rawValue:)) {
                    state.settings.mode = mode
                }
                if let enabled = message["enabled"] as? Bool { state.settings.enabled = enabled }
                state.settings.updatedAt = updatedAt
            }
            Bridge.post(Bridge.settingsChanged, state.settings)
            return ["ok": true, "settings": payload(state.settings)]
        default:
            return ["ok": false, "error": "unknown message"]
        }
    }

    private func payload(_ settings: TimepriceSettings) -> [String: Any] {
        [
            "salary": settings.salary,
            "mode": settings.mode.rawValue,
            "enabled": settings.enabled,
            "updatedAt": settings.updatedAt,
        ]
    }
}
