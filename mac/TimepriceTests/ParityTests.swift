import JavaScriptCore
import XCTest

/// Runs the shipped `extension/core.js` in JavaScriptCore and checks that the
/// Swift port produces identical results, so the notch app and the browser
/// extension can never disagree about what a salary is worth.
final class ParityTests: XCTestCase {
    private static let coreURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("extension/core.js")

    private var js: JSContext!

    override func setUpWithError() throws {
        js = JSContext()
        js.exceptionHandler = { _, exception in XCTFail("JS exception: \(exception?.toString() ?? "?")") }
        let source = try String(contentsOf: Self.coreURL, encoding: .utf8)
        js.evaluateScript(source, withSourceURL: Self.coreURL)
        XCTAssertFalse(js.evaluateScript("typeof Timeprice").toString() == "undefined")
    }

    private func jsEstimate(_ salary: Double, _ mode: TimeMode) -> [String: Double] {
        // Read numbers straight from JSValues: a JSON round trip through
        // Foundation can perturb the last bit and hide (or fake) differences.
        let value = js.evaluateScript("Timeprice.estimate(\(salary), '\(mode.rawValue)')")!
        let keys = ["salary", "social", "irpf", "net", "annualHours", "dayHours", "perMinute", "perHour", "perDay"]
        return Dictionary(uniqueKeysWithValues: keys.map { ($0, value.forProperty($0).toDouble()) })
    }

    static let salaries: [Double] = [
        1, 4_999.99, 9_000, 14_000, 15_876.5, 16_500, 18_000, 19_000, 21_000, 25_000, 32_000,
        41_000, 50_981, 61_214.4, 64_000, 70_000, 85_000, 92_000, 120_000, 300_000, 1_000_000, 10_000_000,
    ]

    func testEstimateMatchesCoreJS() throws {
        for salary in Self.salaries + Array(stride(from: 500.0, through: 400_000, by: 1_337.77)) {
            for mode in TimeMode.allCases {
                let swift = try SalaryModel.estimate(salary, mode: mode)
                let js = jsEstimate(salary, mode)
                let pairs: [(String, Double)] = [
                    ("salary", swift.salary), ("social", swift.social), ("irpf", swift.irpf), ("net", swift.net),
                    ("annualHours", swift.annualHours), ("dayHours", swift.dayHours),
                    ("perMinute", swift.perMinute), ("perHour", swift.perHour), ("perDay", swift.perDay),
                ]
                for (key, value) in pairs {
                    let expected = try XCTUnwrap(js[key], "\(key) missing for \(salary)")
                    // Same operations in the same order: results must be identical.
                    XCTAssertEqual(value, expected, "\(key) for €\(salary) (\(mode))")
                }
            }
        }
    }

    func testRejectsTheSameSalariesAsCoreJS() {
        for salary in [0, -1, 10_000_001, Double.nan, .infinity] {
            XCTAssertThrowsError(try SalaryModel.estimate(salary))
            let threw = js.evaluateScript(
                "(() => { try { Timeprice.estimate(\(salary.isNaN ? "NaN" : salary.isInfinite ? "Infinity" : String(salary))); return false } catch { return true } })()"
            )!.toBool()
            XCTAssertTrue(threw, "core.js should reject \(salary)")
        }
    }

    func testDurationMatchesCoreJS() throws {
        let prices: [Double] = [0, 0.01, 1, 9.99, 49, 100, 129.9 / 1.1622, 279, 399.99, 1_319, 2_499, 12_000, 54_321.5]
        for salary in [18_000.0, 50_981, 120_000] {
            for mode in TimeMode.allCases {
                let perMinute = try SalaryModel.estimate(salary, mode: mode).perMinute
                for price in prices {
                    let expected = js.evaluateScript(
                        "Timeprice.duration(\(price), Timeprice.estimate(\(salary), '\(mode.rawValue)').perMinute, '\(mode.rawValue)')"
                    )!.toString()
                    XCTAssertEqual(
                        SalaryModel.duration(price, perMinute: perMinute, mode: mode), expected,
                        "€\(price) at €\(salary) (\(mode))")
                }
            }
        }
        XCTAssertEqual(SalaryModel.duration(-1, perMinute: 1), js.evaluateScript("Timeprice.duration(-1, 1)").toString())
        XCTAssertEqual(SalaryModel.duration(1, perMinute: 0), js.evaluateScript("Timeprice.duration(1, 0)").toString())
    }

    /// Default-salary values shown in the app and the showcase assets.
    func testDefaultSalaryReferenceValues() throws {
        let work = try SalaryModel.estimate(50_981, mode: .work)
        let all = try SalaryModel.estimate(50_981, mode: .all)
        XCTAssertEqual(SalaryModel.duration(100, perMinute: work.perMinute, mode: .work), "5h 45m")
        XCTAssertEqual(SalaryModel.duration(100, perMinute: all.perMinute, mode: .all), "1d 0h 15m")
        XCTAssertEqual(SalaryModel.duration(279, perMinute: work.perMinute, mode: .work), "2d 0h 4m")
    }
}
