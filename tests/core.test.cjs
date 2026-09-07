const { test } = require("node:test");
const assert = require("node:assert/strict");
const T = require("../extension/core.js");
test("public default calculation and all-time denominator", () => {
  const e = T.estimate(T.defaults.salary);
  assert.equal(e.salary, 50981);
  assert.equal(e.annualHours, 8760);
  assert.equal(e.perMinute, e.net / 525600);
});
test("input validation and bracket boundaries", () => {
  for (const x of [0, -1, NaN, Infinity, 10000001])
    assert.throws(() => T.estimate(x));
  let last = 0;
  for (let x = 1; x <= 1000000; x += 137) {
    const e = T.estimate(x);
    assert.ok(e.net > 0 && e.net <= x);
    assert.ok(e.net > last);
    last = e.net;
  }
});
test("euro price formats", () => {
  for (const [s, n] of [
    ["19,99 €", 19.99],
    ["€19.99", 19.99],
    ["1.299,00 €", 1299],
    ["EUR 1,299.00", 1299],
    ["1 299,00 €", 1299],
    ["1\u202f299 €", 1299],
    ["1.299 €", 1299],
    ["0,00 €", 0],
  ])
    assert.equal(T.prices(s)[0]?.value, n, s);
});
test("reject unsupported and malformed prices", () => {
  for (const s of ["100 RUB", "2026", "-10 €", "12,34,56 €"])
    assert.equal(T.prices(s).length, 0, s);
});
test("multiple prices and durations with carry", () => {
  assert.deepEqual(
    T.prices("From 10 € to 30 €").map((p) => p.value),
    [10, 30],
  );
  assert.equal(T.duration(0, 1), "0h 0m");
  assert.equal(T.duration(0.1, 1), "0h 0m");
  assert.equal(T.duration(59.6, 1), "1h 0m");
  assert.equal(T.duration(1439.6, 1), "1d 0h 0m");
  assert.equal(T.duration(2879, 1), "1d 23h 59m");
});
test("work-hour denominator with eight-hour workdays", () => {
  const e = T.estimate(T.defaults.salary, "work");
  assert.equal(e.annualHours, 2080);
  assert.equal(e.perMinute, e.net / 124800);
  assert.equal(e.perDay, e.net / 260);
  assert.equal(T.duration(8 * 60, 1, "work"), "1d 0h 0m");
  assert.equal(T.duration(16 * 60, 1, "work"), "2d 0h 0m");
});
test("currencies, explicit qualifiers, ranges and conversion direction", () => {
  const cases = [
    ["$169.90", "USD", 169.9],
    ["£99.99", "GBP", 99.99],
    ["CHF 1,299.90", "CHF", 1299.9],
    ["CA$100", "CAD", 100],
    ["A$100", "AUD", 100],
    ["NZ$100", "NZD", 100],
    ["HK$100", "HKD", 100],
    ["S$100", "SGD", 100],
    ["R$99,90", "BRL", 99.9],
    ["₹100", "INR", 100],
    ["¥1000", "JPY", 1000],
    ["100 USD", "USD", 100],
    ["100 zł", "PLN", 100],
  ];
  for (const [input, code, amount] of cases) {
    const p = T.prices(input)[0];
    assert.equal(p?.currency, code, input);
    assert.equal(p?.value, amount, input);
  }
  assert.equal(T.prices("$100", { dollar: "CAD" })[0].currency, "CAD");
  assert.equal(T.prices("$100 USD", { dollar: "CAD" })[0].currency, "USD");
  assert.equal(T.prices("kr 100").length, 0);
  assert.equal(T.prices("100 kr", { currency: "SEK" })[0].currency, "SEK");
  assert.equal(T.prices("$100-200")[0].valueEnd, 200);
  assert.equal(T.toEuros(120, "USD", { rates: { USD: 1.2 } }), 100);
  assert.equal(T.toEuros(100, "EUR", null), 100);
  assert.equal(T.toEuros(100, "CAD", { rates: { USD: 1.2 } }), null);
});
test("Swiss and Indian grouping are parsed whole, not as partial prices", () => {
  for (const [input, n] of [
    ["CHF 1'299.90", 1299.9],
    ["CHF 1’299.90", 1299.9],
    ["₹1,29,999.00", 129999],
    ["INR 1,29,999", 129999],
  ])
    assert.equal(T.prices(input)[0]?.value, n, input);
  assert.equal(T.prices("$100 ARS").length, 0);
  assert.equal(T.prices("CHF 1'29").length, 0);
});
