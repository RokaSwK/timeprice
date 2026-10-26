import SwiftUI

/// Everything drawn inside the notch window. The black shape is anchored to the
/// top edge and morphs between states; content cross-fades inside it.
struct NotchRootView: View {
    var model: NotchModel

    var body: some View {
        let size = model.size
        let metrics = model.metrics
        ZStack(alignment: .top) {
            NotchShape(topRadius: metrics.ear, bottomRadius: metrics.bottomRadius(for: model.presentation))
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(model.presentation.isRest ? 0 : 0.5), radius: 22, y: 10)
            content
                .padding(.horizontal, metrics.ear)
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(NotchShape(topRadius: metrics.ear, bottomRadius: metrics.bottomRadius(for: model.presentation)))
        }
        .contentShape(NotchShape(topRadius: metrics.ear, bottomRadius: metrics.bottomRadius(for: model.presentation)))
        .onTapGesture {
            // Inside the panel, taps belong to its controls; it closes on exit or Esc.
            if model.presentation != .panel { model.tap() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.presentation)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.snapshot.isWorking)
    }

    @ViewBuilder private var content: some View {
        switch model.presentation {
        case .rest:
            RestView(model: model).transition(.opacity)
        case .expanded:
            ExpandedView(model: model).transition(.blurFade)
        case .alert(let event):
            PriceAlertView(model: model, event: event).transition(.blurFade)
        case .panel:
            PanelView(model: model).transition(.blurFade)
        }
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)).animation(.easeOut(duration: 0.25).delay(0.08)),
            removal: .opacity.animation(.easeIn(duration: 0.12)))
    }
}

/// Live amount with the cents emphasised and sub-cent digits that visibly tick.
struct TickerText: View {
    var amount: Double
    var size: CGFloat
    var showsFraction = false
    var color: Color = Theme.primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(Money.euro(amount))
                .font(Theme.rounded(size))
                .foregroundStyle(color)
                .contentTransition(.numericText(value: amount))
            if showsFraction {
                Text(String(format: "%02d", Int((amount * 10000).rounded(.down)) % 100))
                    .font(Theme.rounded(size * 0.42, .medium))
                    .foregroundStyle(Theme.tertiary)
                    .contentTransition(.numericText(value: amount))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
    }
}

/// Status row that sits beside the hardware notch in every expanded state.
struct NotchHeader: View {
    var model: NotchModel
    var leading: String = "Timeprice"

    var body: some View {
        let snapshot = model.snapshot
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                TimepriceMark(size: 16)
                Text(leading)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.leading, 18)
            Spacer(minLength: model.metrics.notchWidth + 16)
            HStack(spacing: 5) {
                Circle()
                    .fill(snapshot.isWorking ? Theme.mint : Theme.tertiary)
                    .frame(width: 6, height: 6)
                TickerText(amount: snapshot.today, size: 12.5, color: snapshot.isWorking ? Theme.mint : Theme.secondary)
            }
            .padding(.trailing, 18)
        }
        .frame(height: model.metrics.notchHeight)
    }
}

struct RestView: View {
    var model: NotchModel

    var body: some View {
        let snapshot = model.snapshot
        HStack(spacing: 0) {
            HStack {
                TimepriceMark(size: 18)
                    .opacity(model.settings.enabled ? 1 : 0.4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 13)
            Spacer(minLength: model.metrics.hasNotch ? model.metrics.notchWidth : 10)
            Group {
                if snapshot.isWorking {
                    TickerText(amount: snapshot.today, size: 13, color: Theme.mint)
                } else {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 13)
        }
        .frame(height: model.metrics.notchHeight)
    }
}

struct ExpandedView: View {
    var model: NotchModel

    var body: some View {
        let s = model.snapshot
        VStack(alignment: .leading, spacing: 0) {
            NotchHeader(model: model, leading: s.isWorking ? "Earning" : "Off the clock")
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        TickerText(amount: s.today, size: 36, showsFraction: true)
                        Text(s.isWorking ? "earned today so far" : "earned today")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Money.euro(s.perHour) + "/h")
                            .font(Theme.rounded(17))
                            .foregroundStyle(Theme.mint)
                            .monospacedDigit()
                        Text("net hourly rate")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                }
                WorkdayBar(snapshot: s, schedule: model.settings.schedule)
                HStack(spacing: 8) {
                    StatTile(title: "This week", value: Money.euro(s.week))
                    StatTile(title: "This month", value: Money.euro(s.month))
                    StatTile(title: "Full day pays", value: Money.euro(s.dayTarget))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

struct WorkdayBar: View {
    var snapshot: EarningsSnapshot
    var schedule: WorkSchedule

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.mintDeep, Theme.mint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * snapshot.workdayProgress))
                        .opacity(snapshot.workdayProgress > 0 ? 1 : 0)
                }
            }
            .frame(height: 6)
            HStack {
                Text(Clock.string(schedule.start))
                Spacer()
                Text(label)
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text(Clock.string(schedule.end))
            }
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
            .foregroundStyle(Theme.tertiary)
        }
    }

    private var label: String {
        if !snapshot.isWorkday { return "Day off" }
        if snapshot.workdayProgress >= 1 { return "Workday done" }
        if snapshot.workdayProgress <= 0 { return "Workday starts \(Clock.string(schedule.start))" }
        let left = snapshot.closes.timeIntervalSince(snapshot.date)
        let h = Int(left) / 3600, m = (Int(left) % 3600) / 60
        return "\(Int((snapshot.workdayProgress * 100).rounded()))% of workday · \(h)h \(m)m left"
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.tertiary)
            Text(value)
                .font(Theme.rounded(14))
                .monospacedDigit()
                .foregroundStyle(accent ? Theme.mint : Theme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.card))
    }
}

struct PriceAlertView: View {
    var model: NotchModel
    var event: PriceEvent

    var body: some View {
        VStack(spacing: 0) {
            NotchHeader(model: model, leading: "Price spotted")
            HStack(spacing: 13) {
                HostBadge(host: event.host, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                    Text("\(event.host) · \(event.original)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(event.duration(for: model.settings))
                        .font(Theme.rounded(24))
                        .foregroundStyle(Theme.mint)
                        .monospacedDigit()
                        .fixedSize()
                    Text(model.settings.mode.phrase)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }
}

/// Monogram for the shop a price came from (no favicons: nothing is fetched).
struct HostBadge: View {
    var host: String
    var size: CGFloat

    var body: some View {
        let name = host.replacingOccurrences(of: "www.", with: "")
        let letter = name.first.map { String($0).uppercased() } ?? "€"
        let hue = Double(name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }) / 360
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hue: hue, saturation: 0.35, brightness: 0.42), Color(hue: hue, saturation: 0.45, brightness: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                Text(letter)
                    .font(Theme.rounded(size * 0.44, .bold))
                    .foregroundStyle(.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .frame(width: size, height: size)
    }
}

extension TimeMode {
    var phrase: String { self == .work ? "of work" : "of your time" }
    var title: String { self == .work ? "Work time" : "All time" }
    var detail: String { self == .work ? "40 h × 52 weeks · 8 h days" : "24 h × 365 days" }
}

enum Clock {
    static func string(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
