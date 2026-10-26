const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");
const chrome = JSON.parse(fs.readFileSync("extension/manifest.json", "utf8"));
const safari = JSON.parse(
  fs.readFileSync("mac/SafariWeb/manifest.json", "utf8"),
);
const settle = () => new Promise((r) => setTimeout(r, 50));

test("Safari manifest reuses the Chrome extension without drifting", () => {
  for (const key of ["version", "name", "description", "action"])
    assert.deepEqual(safari[key], chrome[key], key);
  assert.deepEqual(safari.host_permissions, chrome.host_permissions);
  assert.deepEqual(safari.permissions, [
    ...chrome.permissions,
    "nativeMessaging",
  ]);
  const [c] = chrome.content_scripts,
    [s] = safari.content_scripts;
  assert.deepEqual(s.js, [...c.js, "safari-bridge.js"]);
  assert.deepEqual(s.css, c.css);
  assert.deepEqual(s.matches, c.matches);
  assert.equal(s.run_at, c.run_at);
  assert.ok(
    safari.background.scripts.includes(chrome.background.service_worker),
  );
  const referenced = [
    safari.action.default_popup,
    ...safari.background.scripts,
    ...s.js,
    ...s.css,
  ];
  for (const file of referenced)
    assert.ok(
      fs.existsSync(path.join("extension", file)) ||
        fs.existsSync(path.join("mac/SafariWeb", file)),
      `Missing ${file}`,
    );
  // Safari files only add to the shared sources; they never shadow them.
  for (const file of fs.readdirSync("mac/SafariWeb"))
    assert.ok(
      !fs.existsSync(path.join("extension", file)) || file === "manifest.json",
      file,
    );
});

async function bridge(html, stored = {}) {
  const dom = new JSDOM(html, {
    runScripts: "outside-only",
    url: "https://www.demostore.example/es/airpods-pro-3",
  });
  const sent = [];
  dom.window.chrome = {
    storage: {
      local: { get: async (d) => ({ ...d, ...stored }) },
      onChanged: { addListener() {} },
    },
    runtime: { sendMessage: async (m) => sent.push(m) },
  };
  Object.defineProperty(dom.window.document, "visibilityState", {
    value: "visible",
  });
  for (const file of [
    "extension/fx.js",
    "extension/core.js",
    "mac/SafariWeb/safari-bridge.js",
  ])
    dom.window.eval(fs.readFileSync(file, "utf8"));
  await settle();
  dom.window.close();
  return sent;
}

test("Safari bridge reports the product price on the demo page", async () => {
  const sent = await bridge(fs.readFileSync("mac/Demo/product.html", "utf8"));
  assert.equal(sent[0].type, "timeprice-sync");
  const seen = sent.find((m) => m.type === "timeprice-price-seen");
  assert.equal(seen.title, "AirPods Pro 3");
  assert.equal(seen.host, "demostore.example");
  assert.equal(seen.amount, 279);
  assert.equal(seen.currency, "EUR");
  assert.equal(seen.euros, 279);
  assert.equal(seen.original, "€279.00");
  // Nothing beyond product, shop host and price leaves the page.
  assert.deepEqual(Object.keys(seen).sort(), [
    "amount",
    "currency",
    "euros",
    "host",
    "original",
    "title",
    "type",
  ]);
});

test("Safari bridge uses meta tags, skips non-product pages and respects pause", async () => {
  const meta =
    '<head><meta property="og:title" content="Carry-on"><meta property="product:price:amount" content="129.90"><meta property="product:price:currency" content="USD"></head><body><h1>x</h1></body>';
  const fx = {
    amount: 1,
    base: "EUR",
    date: new Date().toISOString().slice(0, 10),
    rates: { USD: 1.25 },
  };
  const usd = (await bridge(meta, { fx })).find(
    (m) => m.type === "timeprice-price-seen",
  );
  assert.equal(usd.title, "Carry-on");
  assert.equal(usd.amount, 129.9);
  assert.equal(usd.euros, 129.9 / 1.25);
  const plain = await bridge("<body><p>Only 10 € today</p></body>");
  assert.equal(
    plain.filter((m) => m.type === "timeprice-price-seen").length,
    0,
  );
  const paused = await bridge(meta, { fx, enabled: false });
  assert.equal(
    paused.filter((m) => m.type === "timeprice-price-seen").length,
    0,
  );
});
