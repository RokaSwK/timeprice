import Foundation

/// State shared between the notch app and the Safari extension handler.
public struct SharedState: Codable, Equatable, Sendable {
    public var settings: TimepriceSettings
    /// Most recent first.
    public var prices: [PriceEvent]

    public init(settings: TimepriceSettings = .default, prices: [PriceEvent] = []) {
        self.settings = settings
        self.prices = prices
    }

    public static let historyLimit = 40

    public mutating func record(_ event: PriceEvent) {
        // Revisiting the same product replaces the older entry instead of duplicating it.
        prices.removeAll { $0.title == event.title && $0.host == event.host && $0.amount == event.amount }
        prices.insert(event, at: 0)
        if prices.count > Self.historyLimit { prices.removeLast(prices.count - Self.historyLimit) }
    }
}

/// A small JSON file both processes can reach.
///
/// The app is not sandboxed. The Safari extension is (Safari requires it), and
/// its entitlements grant a home-relative read/write exception for
/// `~/Library/Application Support/Timeprice/`, which keeps the bridge working in
/// unsigned/ad-hoc builds where App Group containers are unavailable. A
/// distribution build with a Team ID can point `directory` at an App Group
/// container instead.
public final class SharedStore: @unchecked Sendable {
    public let url: URL
    private let queue = DispatchQueue(label: "Timeprice.SharedStore")

    public init(directory: URL = SharedStore.defaultDirectory) {
        url = directory.appendingPathComponent("shared.json")
    }

    /// `~/Library/Application Support/Timeprice`, resolved against the real home
    /// directory even inside a sandbox container.
    public static var defaultDirectory: URL {
        var home = NSHomeDirectory()
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            home = String(cString: dir)
        }
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/Timeprice", isDirectory: true)
    }

    public func load() -> SharedState {
        queue.sync {
            guard let data = try? Data(contentsOf: url),
                  let state = try? JSONDecoder().decode(SharedState.self, from: data)
            else { return SharedState() }
            return state
        }
    }

    @discardableResult
    public func update(_ change: (inout SharedState) -> Void) -> SharedState {
        queue.sync {
            var state = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(SharedState.self, from: $0) }
                ?? SharedState()
            change(&state)
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(state).write(to: url, options: .atomic)
            } catch {
                NSLog("Timeprice: could not write shared state: \(error.localizedDescription)")
            }
            return state
        }
    }
}

/// Live, cross-process signals. Sandboxed senders may not attach `userInfo` to
/// distributed notifications, so the payload travels as a JSON string in `object`.
public enum Bridge {
    public static let priceSeen = Notification.Name("com.rokaswk.timeprice.price-seen")
    public static let settingsChanged = Notification.Name("com.rokaswk.timeprice.settings-changed")

    public static func post<T: Encodable>(_ name: Notification.Name, _ payload: T) {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8)
        else { return }
        DistributedNotificationCenter.default().postNotificationName(
            name, object: json, userInfo: nil, deliverImmediately: true)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from notification: Notification) -> T? {
        guard let json = notification.object as? String, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
