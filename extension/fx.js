(function (root) {
  "use strict";
  const seed = {
    amount: 1.0,
    base: "EUR",
    date: "2026-09-04",
    rates: {
      AUD: 1.6134,
      BRL: 5.9405,
      CAD: 1.6038,
      CHF: 0.9405,
      CNY: 7.7994,
      CZK: 24.189,
      DKK: 7.4747,
      GBP: 0.85898,
      HKD: 9.112,
      HUF: 363.28,
      IDR: 20496.04,
      ILS: 3.4954,
      INR: 109.8165,
      ISK: 140.8,
      JPY: 181.59,
      KRW: 1569.38,
      MXN: 19.6401,
      MYR: 4.7005,
      NOK: 10.8035,
      NZD: 1.9755,
      PHP: 72.812,
      PLN: 4.3148,
      RON: 5.253,
      SEK: 11.1005,
      SGD: 1.4724,
      THB: 38.26,
      TRY: 56.2995,
      USD: 1.1622,
      ZAR: 18.5571,
    },
  };
  function valid(data, now = Date.now()) {
    if (
      !data ||
      data.base !== "EUR" ||
      data.amount !== 1 ||
      !/^\d{4}-\d{2}-\d{2}$/.test(data.date || "") ||
      !data.rates ||
      typeof data.rates !== "object"
    )
      return false;
    const age = now - Date.parse(data.date + "T00:00:00Z");
    return (
      Number.isFinite(age) &&
      age >= -86400000 &&
      age <= 14 * 86400000 &&
      Object.entries(data.rates).length > 0 &&
      Object.entries(data.rates).every(
        ([k, v]) => /^[A-Z]{3}$/.test(k) && Number.isFinite(v) && v > 0,
      )
    );
  }
  function available(cache, now = Date.now()) {
    return valid(cache, now) ? cache : valid(seed, now) ? seed : null;
  }
  const api = { seed, valid, available };
  root.TimepriceFX = api;
  if (typeof module !== "undefined") module.exports = api;
})(globalThis);
