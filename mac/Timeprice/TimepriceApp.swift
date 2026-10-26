import AppKit
import SwiftUI

@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--render-assets") {
            // Hidden showcase mode: render every notch state to PNG, then quit.
            let output = index + 1 < args.count ? args[index + 1] : FileManager.default.currentDirectoryPath
            AssetRenderer.runAndExit(output: URL(fileURLWithPath: output, isDirectory: true), arguments: args)
        } else {
            TimepriceApp.main()
        }
    }
}

struct TimepriceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model)
        } label: {
            Image(systemName: "hourglass")
        }
    }
}

struct MenuContent: View {
    var model: NotchModel

    var body: some View {
        let s = model.snapshot
        Text("Earned today: \(Money.euro(s.today))")
        Text("\(Money.euro(s.perHour))/h net · \(model.settings.mode.title)")
        Divider()
        Button("Today") { model.openPanel(.today) }
        Button("Recent prices") { model.openPanel(.prices) }
        Button("Settings…") { model.openPanel(.settings) }
            .keyboardShortcut(",")
        Divider()
        Button("Show sample price alert") { model.receive(AppDelegate.samplePrice()) }
        Divider()
        Button("Quit Timeprice") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = NotchModel(store: SharedStore())
    private var controller: NotchWindowController?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = NotchWindowController(model: model)
        controller.start()
        self.controller = controller

        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: Bridge.priceSeen, object: nil, queue: .main) { [weak self] note in
            guard let event = Bridge.decode(PriceEvent.self, from: note) else { return }
            MainActor.assumeIsolated { self?.model.receive(event) }
        })
        observers.append(center.addObserver(forName: Bridge.settingsChanged, object: nil, queue: .main) { [weak self] note in
            guard let settings = Bridge.decode(TimepriceSettings.self, from: note) else { return }
            MainActor.assumeIsolated { self?.model.receiveRemote(settings) }
        })

        let args = CommandLine.arguments
        model.pinned = args.contains("--pin")
        if args.contains("--demo-alert") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.model.receive(Self.samplePrice())
            }
        }
        if let i = args.firstIndex(of: "--open"), i + 1 < args.count {
            let state = args[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                switch state {
                case "expanded": self.model.presentation = .expanded
                case "prices": self.model.openPanel(.prices)
                case "settings": self.model.openPanel(.settings)
                default: self.model.openPanel(.today)
                }
            }
        }
    }

    static func samplePrice() -> PriceEvent {
        PriceEvent(title: "AirPods Pro 3", host: "apple.com", original: "€279.00", amount: 279, currency: "EUR", euros: 279)
    }
}
