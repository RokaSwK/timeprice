import Foundation

/// Time basis shared with the browser extension (`mode` in chrome.storage).
public enum TimeMode: String, Codable, CaseIterable, Sendable {
    /// 8,760 hours per year; a displayed day is 24 hours.
    case all
    /// 40 × 52 = 2,080 hours per year; a displayed day is 8 working hours.
    case work
}

/// Swift port of `estimate()` and `duration()` from `extension/core.js`.
///
/// The port is intentionally line-for-line so it can be checked against the
/// JavaScript original. `TimepriceTests/ParityTests.swift` evaluates
/// `extension/core.js` in JavaScriptCore and compares both implementations.
public enum SalaryModel {
    public static let defaultSalary: Double = 50981
    public static let maximumSalary: Double = 10_000_000

    public struct Estimate: Equatable, Sendable {
        public let salary: Double
        public let social: Double
        public let irpf: Double
        public let net: Double
        public let annualHours: Double
        public let dayHours: Double
        public let perMinute: Double
        public let perHour: Double
        public let perDay: Double
    }

    public enum ModelError: Error, LocalizedError, Equatable {
        case outOfRange
        public var errorDescription: String? {
            "Enter a yearly salary greater than €0 and up to €10,000,000."
        }
    }

    private static let brackets: [(limit: Double, rate: Double)] = [
        (12450, 0.19),
        (20200, 0.24),
        (35200, 0.3),
        (60000, 0.37),
        (300_000, 0.45),
        (.infinity, 0.47),
    ]

    static func tax(_ base: Double) -> Double {
        var result = 0.0
        var previous = 0.0
        for (limit, rate) in brackets {
            result += max(0, min(base, limit) - previous) * rate
            previous = limit
            if base <= limit { break }
        }
        return result
    }

    public static func isValid(_ salary: Double) -> Bool {
        salary.isFinite && salary > 0 && salary <= maximumSalary
    }

    public static func estimate(_ salary: Double, mode: TimeMode = .all) throws -> Estimate {
        guard isValid(salary) else { throw ModelError.outOfRange }
        let cap = 5101.2 * 12
        // Each term mirrors core.js, including evaluation order, so floating
        // point results match bit-for-bit.
        let social =
            min(salary, cap) * 0.065
            + max(0, min(salary - cap, cap * 0.1)) * 0.0019
            + max(0, min(salary - cap * 1.1, cap * 0.4)) * 0.0021
            + max(0, salary - cap * 1.5) * 0.0024
        let earnings = salary - social
        let reduction: Double
        if earnings <= 14852 {
            reduction = 7302
        } else if earnings <= 17673.52 {
            reduction = 7302 - 1.75 * (earnings - 14852)
        } else if earnings < 19747.5 {
            reduction = max(0, 2364.34 - 1.14 * (earnings - 17673.52))
        } else {
            reduction = 0
        }
        let taxable = max(0, earnings - 2000 - reduction)
        let irpf = max(0, tax(taxable) - tax(min(taxable, 5550)))
        let net = salary - social - irpf
        let annualHours: Double = mode == .work ? 40 * 52 : 365 * 24
        let dayHours: Double = mode == .work ? 8 : 24
        return Estimate(
            salary: salary,
            social: social,
            irpf: irpf,
            net: net,
            annualHours: annualHours,
            dayHours: dayHours,
            perMinute: net / (annualHours * 60),
            perHour: net / annualHours,
            perDay: (net / annualHours) * dayHours
        )
    }

    /// Same output as `Timeprice.duration(price, perMinute, mode)`, e.g. `2d 3h 0m`.
    public static func duration(_ price: Double, perMinute: Double, mode: TimeMode = .all) -> String {
        guard price.isFinite, price >= 0, perMinute.isFinite, perMinute > 0 else { return "—" }
        let dayMinutes = (mode == .work ? 8 : 24) * 60
        let minutes = Int(jsRound(price / perMinute))
        let days = minutes / dayMinutes
        let hours = (minutes % dayMinutes) / 60
        return "\(days != 0 ? "\(days)d " : "")\(hours)h \(minutes % 60)m"
    }

    /// JavaScript `Math.round`: halves round towards +∞.
    static func jsRound(_ value: Double) -> Double {
        (value + 0.5).rounded(.down)
    }
}
