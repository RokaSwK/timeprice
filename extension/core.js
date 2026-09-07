(function (root) {
  "use strict";
  const defaults = { salary: 50981, enabled: true, mode: "all" };
  const brackets = [
    [12450, 0.19],
    [20200, 0.24],
    [35200, 0.3],
    [60000, 0.37],
    [300000, 0.45],
    [Infinity, 0.47],
  ];
  function tax(base) {
    let result = 0,
      previous = 0;
    for (const [limit, rate] of brackets) {
      result += Math.max(0, Math.min(base, limit) - previous) * rate;
      previous = limit;
      if (base <= limit) break;
    }
    return result;
  }
  function estimate(salary, mode = "all") {
    if (!Number.isFinite(salary) || salary <= 0 || salary > 10000000)
      throw new RangeError(
        "Enter a yearly salary greater than €0 and up to €10,000,000.",
      );
    const cap = 5101.2 * 12;
    const social =
      Math.min(salary, cap) * 0.065 +
      Math.max(0, Math.min(salary - cap, cap * 0.1)) * 0.0019 +
      Math.max(0, Math.min(salary - cap * 1.1, cap * 0.4)) * 0.0021 +
      Math.max(0, salary - cap * 1.5) * 0.0024;
    const earnings = salary - social;
    const reduction =
      earnings <= 14852
        ? 7302
        : earnings <= 17673.52
          ? 7302 - 1.75 * (earnings - 14852)
          : earnings < 19747.5
            ? Math.max(0, 2364.34 - 1.14 * (earnings - 17673.52))
            : 0;
    const taxable = Math.max(0, earnings - 2000 - reduction);
    const irpf = Math.max(0, tax(taxable) - tax(Math.min(taxable, 5550)));
    const net = salary - social - irpf;
    const annualHours = mode === "work" ? 40 * 52 : 365 * 24;
    const dayHours = mode === "work" ? 8 : 24;
    return {
      salary,
      social,
      irpf,
      net,
      annualHours,
      dayHours,
      perMinute: net / (annualHours * 60),
      perHour: net / annualHours,
      perDay: (net / annualHours) * dayHours,
    };
  }
  function parseAmount(raw) {
    let s = raw.trim();
    // Accept space/Swiss grouping only in complete groups of three digits.
    if (/[\s'’]/.test(s)) {
      if (!/^\d{1,3}(?:[\s'’]\d{3})+(?:[.,]\d{1,2})?$/.test(s)) return null;
      s = s.replace(/[\s'’]/g, "");
    }
    if (!/^\d[\d.,]*$/.test(s)) return null;
    const comma = s.lastIndexOf(","),
      dot = s.lastIndexOf(".");
    const grouped = (value, sep) => {
      const parts = value.split(sep);
      return (
        (/^\d{1,3}$/.test(parts[0]) &&
          parts.slice(1).every((p) => /^\d{3}$/.test(p))) ||
        (sep === "," && /^\d{1,2}(?:,\d{2})*,\d{3}$/.test(value))
      );
    };
    if (comma >= 0 && dot >= 0) {
      const decimal = comma > dot ? "," : ".",
        separator = decimal === "," ? "." : ",";
      const parts = s.split(decimal);
      if (
        parts.length !== 2 ||
        !/^\d{1,2}$/.test(parts[1]) ||
        !grouped(parts[0], separator)
      )
        return null;
      s = parts[0].split(separator).join("") + "." + parts[1];
    } else if (comma >= 0 || dot >= 0) {
      const separator = comma >= 0 ? "," : ".",
        parts = s.split(separator);
      if (parts.length === 2 && /^\d{1,2}$/.test(parts[1])) s = parts.join(".");
      else if (grouped(s, separator)) s = parts.join("");
      else return null;
    }
    const value = Number(s);
    return Number.isFinite(value) && value >= 0 ? value : null;
  }
  const currencies =
    "EUR USD GBP CHF CAD AUD NZD JPY CNY HKD SGD INR BRL MXN SEK NOK DKK PLN CZK HUF RON TRY ZAR KRW THB IDR MYR PHP ILS ISK".split(
      " ",
    );
  const symbols = {
    "€": "EUR",
    "£": "GBP",
    US$: "USD",
    CA$: "CAD",
    C$: "CAD",
    AU$: "AUD",
    A$: "AUD",
    NZ$: "NZD",
    HK$: "HKD",
    SG$: "SGD",
    S$: "SGD",
    R$: "BRL",
    MX$: "MXN",
    "CN¥": "CNY",
    "JP¥": "JPY",
    "₹": "INR",
    "₩": "KRW",
    "฿": "THB",
    "₺": "TRY",
    "₱": "PHP",
    "₪": "ILS",
    ZŁ: "PLN",
  };
  function currencyFor(token, context = {}) {
    const code = token.toUpperCase().trim();
    if (currencies.includes(code)) return code;
    if (code === "$") return context.dollar || "USD";
    if (code === "¥" || code === "￥") return context.yen || "JPY";
    if (code === "KR")
      return ["SEK", "NOK", "DKK", "ISK"].includes(context.currency)
        ? context.currency
        : null;
    return symbols[code] || null;
  }
  function prices(text, context = {}) {
    const number =
      "\\d(?:[\\d.,'’]*\\d)?(?:[ \\u00a0\\u202f]\\d{3})*(?:[.,]\\d{1,2})?";
    const iso = currencies.join("|");
    const token =
      "(?:US\\$|CA\\$|C\\$|AU\\$|A\\$|NZ\\$|HK\\$|SG\\$|S\\$|R\\$|MX\\$|CN¥|JP¥|" +
      iso +
      "|kr|zł|[€$£¥￥₹₩฿₺₱₪])";
    const re = new RegExp(
      "(" +
        token +
        ")\\s*(" +
        number +
        ")(?:\\s*([-–—])\\s*(" +
        number +
        "))?(?:\\s*(" +
        iso +
        "))?|(" +
        number +
        ")(?:\\s*([-–—])\\s*(" +
        number +
        "))?\\s*(" +
        token +
        ")",
      "gi",
    );
    const result = [];
    for (const m of text.matchAll(re)) {
      const before = text[m.index - 1] || "",
        after = text[m.index + m[0].length] || "";
      if (/[\w.,'’\-−]/.test(before) || /[\w'’]/.test(after)) continue;
      if (
        /^\s+(?:ARS|CLP|TWD|RUB|AED|SAR|KWD|COP|UYU)\b/i.test(
          text.slice(m.index + m[0].length),
        )
      )
        continue;
      const value = parseAmount(m[2] || m[6]);
      const endRaw = m[4] || m[8];
      const valueEnd = endRaw ? parseAmount(endRaw) : undefined;
      const firstCode = currencyFor(m[1] || m[9], context);
      const suffix = m[5];
      // A bare dollar/yen with a trailing ISO code uses the explicit code.
      if (
        suffix &&
        !["$", "¥", "￥"].includes(m[1]) &&
        firstCode !== suffix.toUpperCase()
      )
        continue;
      const currency = suffix ? suffix.toUpperCase() : firstCode;
      if (value !== null && currency && (!endRaw || valueEnd !== null))
        result.push({
          index: m.index,
          length: m[0].length,
          original: m[0],
          value,
          currency,
          ...(endRaw ? { valueEnd } : {}),
        });
    }
    return result;
  }
  function toEuros(value, currency, fx) {
    if (currency === "EUR") return value;
    const rate = fx?.rates?.[currency];
    return Number.isFinite(rate) && rate > 0 ? value / rate : null;
  }
  function duration(price, perMinute, mode = "all") {
    if (
      !Number.isFinite(price) ||
      price < 0 ||
      !Number.isFinite(perMinute) ||
      perMinute <= 0
    )
      return "—";
    const dayMinutes = (mode === "work" ? 8 : 24) * 60;
    const minutes = Math.round(price / perMinute);
    const days = Math.floor(minutes / dayMinutes);
    const hours = Math.floor((minutes % dayMinutes) / 60);
    return `${days ? `${days}d ` : ""}${hours}h ${minutes % 60}m`;
  }
  const api = {
    defaults,
    estimate,
    parseAmount,
    prices,
    duration,
    currencies,
    toEuros,
    currencyFor,
  };
  root.Timeprice = api;
  if (typeof module !== "undefined") module.exports = api;
})(globalThis);
