const { test } = require("node:test");
const assert = require("node:assert/strict");
const vm = require("node:vm");
const fs = require("node:fs");
const FX = require("../extension/fx.js");
test("expired, invalid and unavailable FX are rejected", () => {
  const today = Date.parse("2026-09-06T12:00:00Z");
  assert.equal(FX.valid(FX.seed, today), true);
  assert.equal(FX.valid({ ...FX.seed, date: "2026-08-01" }, today), false);
  assert.equal(FX.valid({ ...FX.seed, rates: { USD: -1 } }, today), false);
  assert.equal(FX.valid({ ...FX.seed, base: "USD" }, today), false);
  assert.equal(FX.available(null, Date.parse("2027-01-01")), null);
});
test("background caches rates, deduplicates requests, and falls back on failure", async () => {
  let calls = 0,
    fail = false;
  const saved = {};
  const context = {
    TimepriceFX: {
      ...FX,
      valid: (d) => FX.valid(d, Date.parse("2026-09-06T12:00:00Z")),
      available: (d) => FX.available(d, Date.parse("2026-09-06T12:00:00Z")),
    },
    Date,
    AbortSignal,
    importScripts: () => {},
    chrome: {
      storage: {
        local: {
          get: async () => ({ ...saved }),
          set: async (v) => Object.assign(saved, v),
        },
      },
      runtime: {
        onMessage: { addListener: () => {} },
        onInstalled: { addListener: () => {} },
        onStartup: { addListener: () => {} },
      },
    },
    fetch: async (url, options) => {
      calls++;
      assert.equal(url, "https://api.frankfurter.dev/v1/latest?base=EUR");
      assert.equal(options.credentials, "omit");
      if (fail) throw Error("offline");
      return { ok: true, json: async () => FX.seed };
    },
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync("extension/background.js", "utf8"), context);
  await Promise.all([context.getRates(), context.getRates()]);
  assert.equal(calls, 1);
  await context.getRates();
  assert.equal(calls, 1);
  fail = true;
  const cached = await context.getRates(true);
  assert.equal(cached.date, FX.seed.date);
  assert.equal(saved.fxError, "offline");
});
