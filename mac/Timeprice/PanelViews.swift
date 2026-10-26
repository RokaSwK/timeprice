import SwiftUI

struct PanelView: View {
    var model: NotchModel

    var body: some View {
        VStack(spacing: 0) {
            NotchHeader(model: model)
            TabBar(selection: Binding(get: { model.tab }, set: { model.tab = $0 }))
                .padding(.top, 10)
                .padding(.horizontal, 22)
            Group {
                switch model.tab {
                case .today: TodayTab(model: model)
                case .prices: PricesTab(model: model)
                case .settings: SettingsTab(model: model)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

struct TabBar: View {
    @Binding var selection: PanelTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PanelTab.allCases) { tab in
                let selected = tab == selection
                HStack(spacing: 6) {
                    Image(systemName: tab.symbol).font(.system(size: 10.5, weight: .semibold))
                    Text(tab.rawValue).font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(selected ? Color.black : Theme.secondary)
                .padding(.horizontal, 13)
                .frame(height: 26)
                .background {
                    if selected {
                        Capsule().fill(Theme.mint).matchedGeometryEffect(id: "tab", in: ns)
                    }
                }
                .contentShape(Capsule())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = tab }
                }
            }
            Spacer()
        }
        .padding(3)
        .background(Capsule().fill(Theme.card))
    }
}

// MARK: Today

struct TodayTab: View {
    var model: NotchModel

    var body: some View {
        let s = model.snapshot
        let estimate = model.settings.estimate
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EARNED TODAY")
                        .font(.system(size: 9.5, weight: .semibold)).tracking(0.7)
                        .foregroundStyle(Theme.tertiary)
                    TickerText(amount: s.today, size: 40, showsFraction: true)
                    Text("\(Money.euro(s.perHour))/h net · \(Money.euro(s.perHour / 60, digits: 4))/min")
                        .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                WeekChart(bars: model.weekBars)
                    .frame(width: 196, height: 84)
            }
            WorkdayBar(snapshot: s, schedule: model.settings.schedule)
            HStack(spacing: 8) {
                StatTile(title: "This week", value: Money.euro(s.week))
                StatTile(title: "This month", value: Money.euro(s.month))
                StatTile(title: "Net per year", value: Money.euro(estimate.net, digits: 0))
                StatTile(
                    title: "€100 costs",
                    value: SalaryModel.duration(100, perMinute: estimate.perMinute, mode: model.settings.mode),
                    accent: true)
            }
        }
    }
}

struct WeekChart: View {
    var bars: [(label: String, amount: Double, target: Double, isToday: Bool)]

    var body: some View {
        let maxTarget = max(bars.map(\.target).max() ?? 1, 0.01)
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                VStack(spacing: 5) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Theme.hairline)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(bar.isToday ? Theme.mint : Theme.mint.opacity(0.45))
                            .frame(height: max(0, 62 * bar.amount / maxTarget))
                    }
                    .frame(height: 62)
                    Text(bar.label)
                        .font(.system(size: 10, weight: bar.isToday ? .bold : .medium))
                        .foregroundStyle(bar.isToday ? Theme.primary : Theme.tertiary)
                }
            }
        }
    }
}

// MARK: Prices

struct PricesTab: View {
    var model: NotchModel
    @Environment(\.isExportRendering) private var exporting

    var body: some View {
        if model.prices.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "safari")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.tertiary)
                Text("No prices yet")
                    .font(.system(size: 14, weight: .semibold))
                Text("Turn on Timeprice in Safari → Settings → Extensions.\nPrices you look at appear here in time.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if exporting {
            list(Array(model.prices.prefix(5)))
        } else {
            ScrollView(.vertical, showsIndicators: false) { list(model.prices) }
        }
    }

    private func list(_ prices: [PriceEvent]) -> some View {
        VStack(spacing: 6) {
            ForEach(prices) { event in
                PriceRow(event: event, settings: model.settings, now: model.now)
            }
        }
    }
}

struct PriceRow: View {
    var event: PriceEvent
    var settings: TimepriceSettings
    var now: Date

    var body: some View {
        HStack(spacing: 11) {
            HostBadge(host: event.host, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text("\(event.host) · \(event.original) · \(ago)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            Text(event.duration(for: settings))
                .font(Theme.rounded(15))
                .monospacedDigit()
                .foregroundStyle(Theme.mint)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
    }

    private var ago: String {
        let seconds = max(0, now.timeIntervalSince1970 - event.seenAt)
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60)) min ago"
        case ..<86400: return "\(Int(seconds / 3600)) h ago"
        default: return "\(Int(seconds / 86400)) d ago"
        }
    }
}

// MARK: Settings

struct SettingsTab: View {
    var model: NotchModel
    @Environment(\.isExportRendering) private var exporting
    @State private var salaryText = ""
    @FocusState private var salaryFocused: Bool

    var body: some View {
        let estimate = model.settings.estimate
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    label("Yearly gross salary")
                    HStack(spacing: 5) {
                        Text("€").foregroundStyle(Theme.tertiary)
                        if exporting {
                            Text(Self.grouped(model.settings.salary))
                        } else {
                            TextField("50981", text: $salaryText)
                                .textFieldStyle(.plain)
                                .focused($salaryFocused)
                                .onSubmit(commitSalary)
                                .onChange(of: salaryFocused) { _, focused in if !focused { commitSalary() } }
                        }
                    }
                    .font(Theme.rounded(20))
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .frame(width: 190, height: 38, alignment: .leading)
                    .background(field)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("≈ \(Money.euro(estimate.net, digits: 0)) net / year")
                        .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                    Text("Spain 2026 estimate · same model as the extension")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(.bottom, 3)
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    label("Work days")
                    DayPicker(days: Binding(
                        get: { model.settings.schedule.days },
                        set: { model.settings.schedule.days = $0 }))
                }
                VStack(alignment: .leading, spacing: 5) {
                    label("Hours")
                    HStack(spacing: 6) {
                        TimeStepper(minutes: Binding(
                            get: { model.settings.schedule.start },
                            set: { model.settings.schedule.start = min($0, model.settings.schedule.end - 30) }))
                        Text("–").foregroundStyle(Theme.tertiary)
                        TimeStepper(minutes: Binding(
                            get: { model.settings.schedule.end },
                            set: { model.settings.schedule.end = max($0, model.settings.schedule.start + 30) }))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                label("Show prices as")
                HStack(spacing: 8) {
                    ForEach([TimeMode.work, .all], id: \.self) { mode in
                        ModeCard(mode: mode, selected: model.settings.mode == mode)
                            .onTapGesture { model.settings.mode = mode }
                    }
                }
            }
            HStack(spacing: 6) {
                Circle().fill(model.extensionSeen ? Theme.mint : Theme.tertiary).frame(width: 6, height: 6)
                Text(model.extensionSeen
                     ? "Salary and time mode sync with the Timeprice Safari extension"
                     : "Enable the Safari extension to sync salary and see prices here")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .onAppear { salaryText = Self.plain(model.settings.salary) }
        .onChange(of: model.settings.salary) { _, value in
            if !salaryFocused { salaryText = Self.plain(value) }
        }
    }

    private func commitSalary() {
        let cleaned = salaryText.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
        if let value = Double(cleaned), SalaryModel.isValid(value) {
            model.settings.salary = value
        }
        salaryText = Self.plain(model.settings.salary)
    }

    private var field: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold)).tracking(0.7)
            .foregroundStyle(Theme.tertiary)
    }

    static func plain(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    static func grouped(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IE")
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? plain(value)
    }
}

struct DayPicker: View {
    @Binding var days: Set<Int>
    /// Monday-first, like a European work week.
    private let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(order, id: \.self) { day in
                let on = days.contains(day)
                Text(Calendar(identifier: .gregorian).veryShortWeekdaySymbols[day - 1])
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(on ? Color.black : Theme.secondary)
                    .frame(width: 27, height: 27)
                    .background(Circle().fill(on ? Theme.mint : Theme.card))
                    .contentShape(Circle())
                    .onTapGesture {
                        if on { days.remove(day) } else { days.insert(day) }
                    }
            }
        }
    }
}

struct TimeStepper: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 0) {
            button("minus") { minutes = max(0, minutes - 30) }
            Text(Clock.string(minutes))
                .font(Theme.rounded(14).monospacedDigit())
                .frame(width: 48)
            button("plus") { minutes = min(24 * 60, minutes + 30) }
        }
        .frame(height: 27)
        .background(Capsule().fill(Theme.card))
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.secondary)
            .frame(width: 24, height: 27)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

struct ModeCard: View {
    var mode: TimeMode
    var selected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: mode == .work ? "briefcase.fill" : "clock.fill")
                .font(.system(size: 13))
                .foregroundStyle(selected ? Theme.mint : Theme.tertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(mode.title).font(.system(size: 12.5, weight: .semibold))
                Text(mode.detail).font(.system(size: 10.5)).foregroundStyle(Theme.tertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(selected ? Theme.mint : Theme.tertiary)
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(selected ? Theme.mint.opacity(0.1) : Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(selected ? Theme.mint.opacity(0.55) : Theme.hairline)))
        .contentShape(Rectangle())
    }
}
