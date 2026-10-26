import Foundation

/// Weekly work schedule. Weekdays use `Calendar` numbering (1 = Sunday … 7 = Saturday).
public struct WorkSchedule: Codable, Equatable, Sendable {
    public var days: Set<Int>
    /// Minutes after midnight.
    public var start: Int
    public var end: Int

    public init(days: Set<Int> = [2, 3, 4, 5, 6], start: Int = 9 * 60, end: Int = 18 * 60) {
        self.days = days
        self.start = start
        self.end = end
    }

    public static let standard = WorkSchedule()

    public var minutesPerDay: Int { max(0, end - start) }
    public var hoursPerWeek: Double { Double(minutesPerDay * days.count) / 60 }
}

/// Settings shared by the app, the Safari extension and (via storage keys) the
/// Chrome extension: `salary`, `mode` and `enabled` mean the same thing everywhere.
public struct TimepriceSettings: Codable, Equatable, Sendable {
    public var salary: Double
    public var mode: TimeMode
    public var enabled: Bool
    public var schedule: WorkSchedule
    /// Seconds since 1970 of the last edit, used to resolve app/extension conflicts.
    public var updatedAt: Double

    public init(
        salary: Double = SalaryModel.defaultSalary,
        mode: TimeMode = .all,
        enabled: Bool = true,
        schedule: WorkSchedule = .standard,
        updatedAt: Double = 0
    ) {
        self.salary = salary
        self.mode = mode
        self.enabled = enabled
        self.schedule = schedule
        self.updatedAt = updatedAt
    }

    public static let `default` = TimepriceSettings()

    public var estimate: SalaryModel.Estimate {
        (try? SalaryModel.estimate(salary, mode: mode))
            ?? (try! SalaryModel.estimate(SalaryModel.defaultSalary, mode: mode))
    }
}

/// Live earnings derived from the net-salary model.
///
/// The hourly rate is the extension's work-time rate
/// (`estimate(salary, "work").perHour`, i.e. net ÷ 2,080 h) so the ticker and
/// work-mode price conversions agree: if a €279 item is "2d 0h 4m" of work, you
/// watch exactly that much money accrue in 16h 4m of scheduled work. Money
/// accrues only inside the work schedule. The time mode only changes how
/// prices are expressed, exactly as in the extension.
public struct EarningsCalculator: Sendable {
    public let settings: TimepriceSettings
    public let calendar: Calendar

    public init(settings: TimepriceSettings, calendar: Calendar = .current) {
        self.settings = settings
        self.calendar = calendar
    }

    public var perHour: Double {
        let salary = SalaryModel.isValid(settings.salary) ? settings.salary : SalaryModel.defaultSalary
        return (try? SalaryModel.estimate(salary, mode: .work).perHour) ?? 0
    }
    public var perSecond: Double { perHour / 3600 }

    /// Seconds of paid time between `from` and `to`.
    public func paidSeconds(from: Date, to: Date) -> Double {
        guard to > from else { return 0 }
        var total = 0.0
        var day = calendar.startOfDay(for: from)
        while day < to {
            let weekday = calendar.component(.weekday, from: day)
            if settings.schedule.days.contains(weekday), settings.schedule.end > settings.schedule.start {
                let open = wallClock(settings.schedule.start, on: day)
                let close = wallClock(settings.schedule.end, on: day)
                let lower = max(open, from)
                let upper = min(close, to)
                if upper > lower { total += upper.timeIntervalSince(lower) }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    /// Local wall-clock time `minutes` after midnight, correct on DST changeover days.
    func wallClock(_ minutes: Int, on day: Date) -> Date {
        let start = calendar.startOfDay(for: day)
        if minutes >= 24 * 60 {
            return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        }
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: start)
            ?? start.addingTimeInterval(Double(minutes) * 60)
    }

    public func earned(from: Date, to: Date) -> Double {
        paidSeconds(from: from, to: to) * perSecond
    }

    public func snapshot(at now: Date) -> EarningsSnapshot {
        let today = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let month = calendar.dateInterval(of: .month, for: now)?.start ?? today
        let weekday = calendar.component(.weekday, from: now)
        let isWorkday = settings.schedule.days.contains(weekday)
        let open = wallClock(settings.schedule.start, on: today)
        let close = wallClock(settings.schedule.end, on: today)
        let progress: Double
        if !isWorkday || close <= open {
            progress = 0
        } else {
            progress = min(1, max(0, now.timeIntervalSince(open) / close.timeIntervalSince(open)))
        }
        let working = isWorkday && now >= open && now < close
        let dayLength = Double(settings.schedule.minutesPerDay) * 60
        return EarningsSnapshot(
            date: now,
            today: earned(from: today, to: now),
            week: earned(from: week, to: now),
            month: earned(from: month, to: now),
            perHour: perHour,
            dayTarget: isWorkday ? dayLength * perSecond : 0,
            workdayProgress: progress,
            isWorking: working,
            isWorkday: isWorkday,
            opens: open,
            closes: close,
            mode: settings.mode
        )
    }
}

public struct EarningsSnapshot: Equatable, Sendable {
    public var date: Date
    public var today: Double
    public var week: Double
    public var month: Double
    public var perHour: Double
    /// What a full scheduled workday pays.
    public var dayTarget: Double
    public var workdayProgress: Double
    public var isWorking: Bool
    public var isWorkday: Bool
    public var opens: Date
    public var closes: Date
    public var mode: TimeMode
}

/// A price the browser extension saw on a page.
public struct PriceEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var host: String
    /// Original price as shown on the page, e.g. "€279,00" or "$129.90".
    public var original: String
    public var amount: Double
    public var currency: String
    /// Converted to euros with the extension's cached reference rates.
    public var euros: Double
    public var seenAt: Double

    public init(
        id: String = UUID().uuidString,
        title: String,
        host: String,
        original: String,
        amount: Double,
        currency: String,
        euros: Double,
        seenAt: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.title = title
        self.host = host
        self.original = original
        self.amount = amount
        self.currency = currency
        self.euros = euros
        self.seenAt = seenAt
    }

    /// Time to earn this price under the given settings, formatted like the extension.
    public func duration(for settings: TimepriceSettings) -> String {
        SalaryModel.duration(euros, perMinute: settings.estimate.perMinute, mode: settings.mode)
    }
}

public enum Money {
    public static func euro(_ value: Double, digits: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "en_IE")
        f.minimumFractionDigits = digits
        f.maximumFractionDigits = digits
        return f.string(from: NSNumber(value: value)) ?? String(format: "€%.\(digits)f", value)
    }
}
