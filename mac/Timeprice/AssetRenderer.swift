import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// `Timeprice --render-assets <dir> [--repo <path>]`
///
/// Renders every notch state with `ImageRenderer` at 2x — once on a dark crop
/// and once composited over a desktop — plus a WebKit capture of the real
/// extension scripts rewriting a local demo product page. Deterministic demo
/// data: €50,981 gross, Mon–Fri 09:00–18:00, Wednesday 28 Oct 2026 14:37:12.
@MainActor
enum AssetRenderer {
    static func runAndExit(output: URL, arguments: [String]) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let repo: URL
        if let i = arguments.firstIndex(of: "--repo"), i + 1 < arguments.count {
            repo = URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
        } else {
            // mac/Timeprice/AssetRenderer.swift → repository root.
            repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
        }
        let frames = arguments.contains("--frames")
        Task { @MainActor in
            do {
                try await render(to: output, repo: repo, frames: frames)
                exit(0)
            } catch {
                FileHandle.standardError.write("render failed: \(error)\n".data(using: .utf8)!)
                exit(1)
            }
        }
        app.run()
        exit(0)
    }

    static let timeZone = TimeZone(identifier: "Europe/Madrid")!

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.firstWeekday = 2
        c.locale = Locale(identifier: "en_GB")
        return c
    }

    static var demoDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 14, minute: 37, second: 12))!
    }

    static var demoSettings: TimepriceSettings {
        TimepriceSettings(salary: 50981, mode: .work, enabled: true, schedule: .standard, updatedAt: 1)
    }

    static var demoPrices: [PriceEvent] {
        let t = demoDate.timeIntervalSince1970
        return [
            PriceEvent(id: "1", title: "AirPods Pro 3", host: "demostore.example", original: "€279.00", amount: 279, currency: "EUR", euros: 279, seenAt: t - 20),
            PriceEvent(id: "2", title: "Sony WH-1000XM6 headphones", host: "amazon.es", original: "€399.99", amount: 399.99, currency: "EUR", euros: 399.99, seenAt: t - 60 * 14),
            PriceEvent(id: "3", title: "Aluminium carry-on suitcase", host: "quince.com", original: "$129.90", amount: 129.9, currency: "USD", euros: 129.9 / 1.1622, seenAt: t - 60 * 47),
            PriceEvent(id: "4", title: "MALM chest of 6 drawers", host: "ikea.com", original: "€179.00", amount: 179, currency: "EUR", euros: 179, seenAt: t - 3600 * 3),
            PriceEvent(id: "5", title: "Nintendo Switch 2", host: "mediamarkt.es", original: "€469.00", amount: 469, currency: "EUR", euros: 469, seenAt: t - 3600 * 26),
            PriceEvent(id: "6", title: "Kindle Paperwhite", host: "amazon.es", original: "€169.99", amount: 169.99, currency: "EUR", euros: 169.99, seenAt: t - 3600 * 50),
        ]
    }

    static func model(_ presentation: Presentation, tab: PanelTab = .today, at date: Date? = nil) -> NotchModel {
        let m = NotchModel(
            store: nil, settings: demoSettings, prices: demoPrices, now: date ?? demoDate,
            metrics: .macBookPro14, calendar: calendar)
        m.presentation = presentation
        m.tab = tab
        m.extensionSeen = true
        return m
    }

    static let states: [(name: String, presentation: Presentation, tab: PanelTab)] = [
        ("at-rest", .rest, .today),
        ("earning-expanded", .expanded, .today),
        ("price-alert", .alert(demoPrices[0]), .today),
        ("panel-today", .panel, .today),
        ("panel-prices", .panel, .prices),
        ("panel-settings", .panel, .settings),
    ]

    static func render(to dir: URL, repo: URL, frames: Bool) async throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pages = try await ProductPageCapture.capture(repo: repo)

        for (name, presentation, tab) in states {
            let m = model(presentation, tab: tab)
            try write(darkCrop(m), to: dir.appendingPathComponent("notch-\(name).png"))
            // The notch alone on transparency, for compositing onto other backdrops.
            try write(NotchRootView(model: m), to: dir.appendingPathComponent("cutout-\(name).png"))
            let desktop = DesktopScene(
                metrics: m.metrics, size: CGSize(width: 1512, height: 560), date: demoDate,
                page: pages.after, timeZone: timeZone
            ) { NotchRootView(model: m) }
            try write(desktop, to: dir.appendingPathComponent("desktop-\(name).png"))
        }

        for (name, image) in [("before", pages.before), ("after", pages.after)] {
            let window = ZStack {
                Wallpaper()
                SafariWindow(page: image, url: "demostore.example/es/airpods-pro-3")
                    .frame(width: 1240, height: 780)
            }
            .frame(width: 1400, height: 900)
            .clipped()
            try write(window, to: dir.appendingPathComponent("safari-extension-\(name).png"))
        }

        if frames {
            // Ticker frames for an MP4: 12 s of the expanded notch, 4 frames per second.
            let frameDir = dir.appendingPathComponent("frames", isDirectory: true)
            try FileManager.default.createDirectory(at: frameDir, withIntermediateDirectories: true)
            for i in 0..<48 {
                let m = model(.expanded, at: demoDate.addingTimeInterval(Double(i) * 0.25))
                try write(darkCrop(m), to: frameDir.appendingPathComponent(String(format: "ticker-%03d.png", i)))
            }
        }
        print("Rendered assets to \(dir.path)")
    }

    static func darkCrop(_ m: NotchModel) -> some View {
        let size = m.size
        let width = max(size.width + 220, 780)
        let height = size.height + 96
        return ZStack(alignment: .top) {
            Color(red: 0.035, green: 0.04, blue: 0.038)
            RadialGradient(
                colors: [Theme.mint.opacity(0.08), .clear], center: .top, startRadius: 0, endRadius: width * 0.55)
            NotchRootView(model: m)
        }
        .frame(width: width, height: height)
    }

    static func write(_ view: some View, to url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.isExportRendering, true))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw RenderError.empty(url.lastPathComponent) }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw RenderError.write(url.path) }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw RenderError.write(url.path) }
        print("  \(url.lastPathComponent) \(image.width)×\(image.height)")
    }

    enum RenderError: Error {
        case empty(String)
        case write(String)
        case page(String)
    }
}

/// Loads `mac/Demo/product.html` in WebKit (the engine Safari uses) and captures
/// it before and after injecting the unmodified extension scripts.
@MainActor
final class ProductPageCapture: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    static func capture(repo: URL) async throws -> (before: NSImage, after: NSImage) {
        let html = try String(contentsOf: repo.appendingPathComponent("mac/Demo/product.html"), encoding: .utf8)
        let ext = repo.appendingPathComponent("extension")
        let scripts = try ["fx.js", "core.js", "content.js"].map {
            try String(contentsOf: ext.appendingPathComponent($0), encoding: .utf8)
        }
        // Minimal stand-in for chrome.storage/runtime, holding the demo settings.
        let shim = """
            globalThis.chrome = {
              storage: {
                local: {
                  get: async (d) => ({ ...(d || {}), salary: 50981, mode: "work", enabled: true, fx: null }),
                  set: async () => {},
                },
                onChanged: { addListener() {} },
              },
              runtime: { sendMessage: async () => ({ ok: true }) },
            };
            """
        let before = try await ProductPageCapture().snapshot(html: html, scripts: [])
        let after = try await ProductPageCapture().snapshot(html: html, scripts: [shim] + scripts)
        return (before, after)
    }

    func snapshot(html: String, scripts: [String]) async throws -> NSImage {
        let config = WKWebViewConfiguration()
        for source in scripts {
            config.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let size = CGSize(width: 1240, height: 740)
        let web = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
        let window = NSWindow(
            contentRect: CGRect(x: -4000, y: -4000, width: size.width, height: size.height),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = web
        window.orderBack(nil)
        defer { window.orderOut(nil) }
        web.navigationDelegate = self
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            continuation = c
            web.loadHTMLString(html, baseURL: URL(string: "https://demostore.example/es/airpods-pro-3"))
        }
        if !scripts.isEmpty {
            // Wait for content.js to rewrite the hero price.
            for _ in 0..<50 {
                let text = try? await web.evaluateJavaScript("document.querySelector('.price').textContent") as? String
                if let text, text.contains("h ") { break }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        try await Task.sleep(for: .milliseconds(300))
        let snap = WKSnapshotConfiguration()
        snap.rect = CGRect(origin: .zero, size: size)
        return try await web.takeSnapshot(configuration: snap)
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
