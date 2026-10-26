import AppKit
import Observation
import SwiftUI

enum Presentation: Equatable {
    case rest
    case expanded
    case alert(PriceEvent)
    case panel

    var isRest: Bool { self == .rest }
}

enum PanelTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case prices = "Prices"
    case settings = "Settings"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "chart.bar.fill"
        case .prices: "tag.fill"
        case .settings: "slider.horizontal.3"
        }
    }
}

/// Geometry of the notch the pill grows out of.
struct NotchMetrics: Equatable {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var hasNotch: Bool

    /// Default 14-inch MacBook Pro scaling.
    static let macBookPro14 = NotchMetrics(notchWidth: 185, notchHeight: 32, hasNotch: true)

    static func from(_ screen: NSScreen?) -> NotchMetrics {
        guard let screen else { return .macBookPro14 }
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea
        {
            return NotchMetrics(
                notchWidth: right.minX - left.maxX,
                notchHeight: screen.safeAreaInsets.top,
                hasNotch: true)
        }
        // No notch: a top-centre pill the height of the menu bar.
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchMetrics(notchWidth: 0, notchHeight: max(24, min(menuBar, 32)), hasNotch: false)
    }

    /// Outer ear radius where the shape meets the screen edge.
    var ear: CGFloat { hasNotch ? 7 : 0 }

    func size(for presentation: Presentation, working: Bool) -> CGSize {
        let gap = hasNotch ? notchWidth : 10
        switch presentation {
        case .rest:
            return CGSize(width: gap + 2 * ear + (working ? 2 * 70 : 2 * 30), height: notchHeight)
        case .expanded:
            return CGSize(width: max(gap + 2 * 118, 430) + 2 * ear, height: notchHeight + 178)
        case .alert:
            return CGSize(width: max(gap + 2 * 132, 460) + 2 * ear, height: notchHeight + 80)
        case .panel:
            return CGSize(width: 560 + 2 * ear, height: notchHeight + 312)
        }
    }

    func bottomRadius(for presentation: Presentation) -> CGFloat {
        switch presentation {
        case .rest: hasNotch ? 11 : notchHeight / 2
        case .expanded, .alert: 26
        case .panel: 30
        }
    }

    /// Largest frame any state needs, plus room for the drop shadow.
    var canvas: CGSize {
        let panel = size(for: .panel, working: true)
        return CGSize(width: panel.width + 120, height: panel.height + 60)
    }
}

@MainActor
@Observable
final class NotchModel {
    var settings: TimepriceSettings {
        didSet { if settings != oldValue { settingsChanged() } }
    }
    var prices: [PriceEvent]
    var now: Date
    var presentation: Presentation = .rest
    var tab: PanelTab = .today
    var metrics: NotchMetrics
    var calendar: Calendar
    /// Whether settings came from / reached the Safari extension.
    var extensionSeen: Bool

    /// Keeps the current state on screen regardless of the pointer (demos, screenshots).
    @ObservationIgnored var pinned = false
    @ObservationIgnored private let store: SharedStore?
    @ObservationIgnored private var saveWork: DispatchWorkItem?
    @ObservationIgnored private var alertWork: DispatchWorkItem?
    @ObservationIgnored private var suppressSave = false

    init(
        store: SharedStore?,
        settings: TimepriceSettings? = nil,
        prices: [PriceEvent]? = nil,
        now: Date = Date(),
        metrics: NotchMetrics = .macBookPro14,
        calendar: Calendar = .current
    ) {
        self.store = store
        let state = store?.load() ?? SharedState()
        self.settings = settings ?? state.settings
        self.prices = prices ?? state.prices
        self.extensionSeen = !(prices ?? state.prices).isEmpty || state.settings.updatedAt > 0
        self.now = now
        self.metrics = metrics
        self.calendar = calendar
    }

    var calculator: EarningsCalculator { EarningsCalculator(settings: settings, calendar: calendar) }
    var snapshot: EarningsSnapshot { calculator.snapshot(at: now) }
    var size: CGSize { metrics.size(for: presentation, working: snapshot.isWorking) }

    /// Earnings for each scheduled day of the current week, for the Today chart.
    var weekBars: [(label: String, amount: Double, target: Double, isToday: Bool)] {
        let calc = calculator
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let weekday = calendar.component(.weekday, from: day)
            guard settings.schedule.days.contains(weekday) else { return nil }
            let end = calendar.date(byAdding: .day, value: 1, to: day)!
            let target = calc.earned(from: day, to: end)
            return (symbols[weekday - 1], calc.earned(from: day, to: min(end, now)), target,
                    calendar.isDate(day, inSameDayAs: now))
        }
    }

    // MARK: Interaction

    func hover(_ inside: Bool) {
        switch (presentation, inside) {
        case (.rest, true): presentation = .expanded
        case (.expanded, false): presentation = .rest
        default: break
        }
    }

    func tap() {
        switch presentation {
        case .panel: presentation = .rest
        case .alert:
            tab = .prices
            presentation = .panel
        default: presentation = .panel
        }
    }

    func openPanel(_ tab: PanelTab) {
        self.tab = tab
        presentation = .panel
    }

    func close() { presentation = .rest }

    func receive(_ event: PriceEvent) {
        prices.removeAll { $0.title == event.title && $0.host == event.host && $0.amount == event.amount }
        prices.insert(event, at: 0)
        if prices.count > SharedState.historyLimit { prices.removeLast(prices.count - SharedState.historyLimit) }
        extensionSeen = true
        guard presentation != .panel else { return }
        presentation = .alert(event)
        alertWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, case .alert = self.presentation else { return }
            self.presentation = .rest
        }
        alertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (pinned ? 30 : 5.5), execute: work)
    }

    /// Settings edited in the Safari extension popup.
    func receiveRemote(_ remote: TimepriceSettings) {
        extensionSeen = true
        guard remote.updatedAt >= settings.updatedAt else { return }
        suppressSave = true
        var merged = settings
        merged.salary = remote.salary
        merged.mode = remote.mode
        merged.enabled = remote.enabled
        merged.updatedAt = remote.updatedAt
        settings = merged
        suppressSave = false
    }

    private func settingsChanged() {
        guard let store, !suppressSave else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            var settings = self.settings
            settings.updatedAt = Date().timeIntervalSince1970
            self.suppressSave = true
            self.settings.updatedAt = settings.updatedAt
            self.suppressSave = false
            store.update { $0.settings = settings }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func clearPrices() {
        prices.removeAll()
        store?.update { $0.prices.removeAll() }
    }
}
