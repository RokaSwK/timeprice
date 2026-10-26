import XCTest

final class EarningsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        c.firstWeekday = 2
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private var calc: EarningsCalculator {
        EarningsCalculator(settings: TimepriceSettings(salary: 50_981, mode: .work), calendar: calendar)
    }

    func testHourlyRateIsTheExtensionWorkRate() throws {
        let expected = try SalaryModel.estimate(50_981, mode: .work).perHour
        XCTAssertEqual(calc.perHour, expected)
        // The time mode changes price formatting, not the pay rate.
        let allMode = EarningsCalculator(settings: TimepriceSettings(salary: 50_981, mode: .all), calendar: calendar)
        XCTAssertEqual(allMode.perHour, expected)
    }

    func testTodayAccruesOnlyInsideTheSchedule() {
        // Wednesday 28 Oct 2026.
        XCTAssertEqual(calc.snapshot(at: date(28, 8, 59)).today, 0)
        XCTAssertEqual(calc.snapshot(at: date(28, 10)).today, calc.perHour, accuracy: 1e-9)
        let hours: Double = 5 + 37.0 / 60 + 12.0 / 3600
        XCTAssertEqual(calc.snapshot(at: date(28, 14, 37, 12)).today, calc.perHour * hours, accuracy: 1e-9)
        XCTAssertEqual(calc.snapshot(at: date(28, 23)).today, calc.perHour * 9, accuracy: 1e-9)
        // Saturday: nothing.
        XCTAssertEqual(calc.snapshot(at: date(31, 12)).today, 0)
    }

    func testWeekAndMonthTotals() {
        let s = calc.snapshot(at: date(28, 14, 37, 12))
        let todayHours: Double = 5 + 37.0 / 60 + 12.0 / 3600
        // Mon + Tue full days plus today so far.
        XCTAssertEqual(s.week, calc.perHour * (18 + todayHours), accuracy: 1e-6)
        // October 2026 workdays before the 28th: 1, 2, 5–9, 12–16, 19–23, 26, 27 = 19 days.
        XCTAssertEqual(s.month, calc.perHour * (19 * 9 + todayHours), accuracy: 1e-6)
        XCTAssertEqual(s.dayTarget, calc.perHour * 9, accuracy: 1e-9)
        XCTAssertTrue(s.isWorking)
        XCTAssertEqual(s.workdayProgress, todayHours / 9, accuracy: 1e-9)
    }

    func testDaylightSavingDayStillCountsScheduledHours() {
        // Spain leaves summer time on Sunday 25 Oct 2026; Monday 26 is a normal 9-hour day.
        XCTAssertEqual(calc.earned(from: date(26, 0), to: date(27, 0)), calc.perHour * 9, accuracy: 1e-6)
        XCTAssertEqual(calc.earned(from: date(24, 0), to: date(26, 0)), 0)
        // A 25-hour changeover day scheduled 09:00–18:00 still pays 9 hours, not 10.
        var everyDay = TimepriceSettings(salary: 50_981, mode: .work)
        everyDay.schedule.days = Set(1...7)
        let sunday = EarningsCalculator(settings: everyDay, calendar: calendar)
        XCTAssertEqual(sunday.earned(from: date(25, 0), to: date(26, 0)), sunday.perHour * 9, accuracy: 1e-6)
        XCTAssertEqual(sunday.earned(from: date(25, 0), to: date(25, 9, 30)), sunday.perHour * 0.5, accuracy: 1e-6)
    }

    func testCustomScheduleAndEmptyDays() {
        var settings = TimepriceSettings(salary: 30_000, mode: .work)
        settings.schedule = WorkSchedule(days: [2, 4], start: 8 * 60, end: 14 * 60 + 30)
        let custom = EarningsCalculator(settings: settings, calendar: calendar)
        // Week of 26 Oct: Monday and Wednesday, 6.5 h each.
        XCTAssertEqual(custom.earned(from: date(26, 0), to: date(2, 0, month: 11)), custom.perHour * 13, accuracy: 1e-6)
        settings.schedule.days = []
        XCTAssertEqual(EarningsCalculator(settings: settings, calendar: calendar).snapshot(at: date(28, 12)).today, 0)
    }

    func testPriceEventDurationUsesSharedFormatting() {
        let event = PriceEvent(title: "AirPods Pro 3", host: "apple.com", original: "€279.00", amount: 279, currency: "EUR", euros: 279)
        XCTAssertEqual(event.duration(for: TimepriceSettings(salary: 50_981, mode: .work)), "2d 0h 4m")
        XCTAssertEqual(event.duration(for: TimepriceSettings(salary: 50_981, mode: .all)), "2d 19h 39m")
    }

    func testSharedStoreRoundTripAndHistoryLimit() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SharedStore(directory: dir)
        XCTAssertEqual(store.load(), SharedState())
        for i in 0..<50 {
            store.update { $0.record(PriceEvent(title: "Item \(i)", host: "shop.example", original: "€\(i)", amount: Double(i), currency: "EUR", euros: Double(i))) }
        }
        store.update { $0.record(PriceEvent(title: "Item 49", host: "shop.example", original: "€49", amount: 49, currency: "EUR", euros: 49)) }
        let state = store.load()
        XCTAssertEqual(state.prices.count, SharedState.historyLimit)
        XCTAssertEqual(state.prices.first?.title, "Item 49")
        XCTAssertEqual(state.prices.filter { $0.title == "Item 49" }.count, 1)
        store.update { $0.settings.salary = 42_000 }
        XCTAssertEqual(store.load().settings.salary, 42_000)
    }
}
