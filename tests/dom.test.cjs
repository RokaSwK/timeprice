const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { JSDOM } = require("jsdom");
const settle = () => new Promise((r) => setTimeout(r, 250));
async function setup(html) {
  const dom = new JSDOM(html, { runScripts: "outside-only" });
  dom.window.Date.now = () => Date.parse("2026-09-06T12:00:00Z");
  let listener;
  dom.window.chrome = {
    storage: {
      local: { get: async (d) => d },
      onChanged: { addListener: (l) => (listener = l) },
    },
  };
  dom.window.eval(fs.readFileSync("extension/fx.js", "utf8"));
  dom.window.eval(fs.readFileSync("extension/core.js", "utf8"));
  dom.window.eval(fs.readFileSync("extension/content.js", "utf8"));
  await settle();
  return {
    dom,
    d: dom.window.document,
    change: async (c) => {
      listener(c, "local");
      await settle();
    },
  };
}
test("native text replacement preserves elements and restores prices; mode and salary update live", async () => {
  const { dom, d, change } = await setup(
    '<body><a id="buy" href="/product" style="font-size:24px">Buy 100 € now</a><p class="price"><b>19</b><sup>,99</sup><span>€</span></p><textarea>20 €</textarea><div contenteditable="true">30 €</div><p>$40</p></body>',
  );
  const a = d.querySelector("a"),
    b = d.querySelector("b");
  assert.equal(a.textContent, "Buy 1d 0h 15m now");
  assert.equal(b.textContent, "4h 51m");
  assert.equal(d.querySelector("sup").textContent, "");
  assert.equal(d.querySelector("textarea").value, "20 €");
  assert.equal(d.querySelector("[contenteditable]").textContent, "30 €");
  assert.equal(d.querySelectorAll(".timeprice-badge").length, 0);
  assert.equal(a.style.fontSize, "24px");
  await change({ mode: { newValue: "work" } });
  assert.equal(a.textContent, "Buy 5h 45m now");
  assert.equal(b.textContent, "1h 9m");
  await change({ salary: { newValue: 60000 } });
  assert.equal(a.textContent, "Buy 5h 1m now");
  await change({ enabled: { newValue: false } });
  assert.equal(a.textContent, "Buy 100 € now");
  assert.equal(b.textContent, "19");
  assert.equal(d.querySelector("sup").textContent, ",99");
  assert.equal(d.querySelector("a"), a);
  assert.equal(d.querySelector("b"), b);
  await change({ enabled: { newValue: true } });
  assert.equal(a.textContent, "Buy 5h 1m now");
  dom.window.close();
});
test("dynamic edits, new prices and partial split updates use fresh site values", async () => {
  const { dom, d, change } = await setup(
    '<p id="p">10 €</p><span class="price"><b>19</b><sup>,99</sup><i>€</i></span>',
  );
  d.querySelector("#p").firstChild.data = "20 €";
  d.querySelector("b").firstChild.data = "29";
  const extra = d.createElement("p");
  extra.textContent = "50 €";
  d.body.append(extra);
  await settle();
  assert.equal(d.querySelector("#p").textContent, "4h 51m");
  assert.equal(d.querySelector(".price").textContent, "7h 16m");
  assert.equal(extra.textContent, "12h 8m");
  await change({ enabled: { newValue: false } });
  assert.equal(d.querySelector(".price").textContent, "29,99€");
  assert.equal(d.querySelector("#p").textContent, "20 €");
  dom.window.close();
});
test("IKEA visible and screen-reader duplicates replace natively without badges", async () => {
  const html =
    '<span data-skapa="price@6.0.1" class="pipcom-price"><span aria-hidden="true"><span class="pipcom-price__integer">19</span><span class="pipcom-price__decimal">,99</span><span class="pipcom-price__currency">€</span></span><span class="pipcom-price__sr-text">El precio 19,99€</span></span>';
  const { dom, d, change } = await setup(html);
  assert.equal(d.querySelector("[aria-hidden]").textContent, "4h 51m");
  assert.equal(d.querySelector(".pipcom-price__sr-text").textContent, "4h 51m");
  await change({ enabled: { newValue: false } });
  assert.equal(d.body.innerHTML, html);
  dom.window.close();
});
for (const site of ["apple", "ikea", "quince"])
  test(`${site} authored storefront fixture restores without changing markup`, async () => {
    const html = fs.readFileSync(`tests/fixtures/${site}.html`, "utf8");
    const baseline = new JSDOM(html);
    const original = baseline.window.document.body.innerHTML;
    const { dom, d, change } = await setup(html);
    assert.notEqual(d.body.innerHTML, original);
    assert.equal(d.querySelectorAll(".timeprice-badge").length, 0);
    await change({ enabled: { newValue: false } });
    assert.equal(d.body.innerHTML, original);
    baseline.window.close();
    dom.window.close();
  });
test("Quince dollar price converts via exchange rate and restores", async () => {
  const { dom, d, change } = await setup(
    '<p id="price">$169.90</p><p id="range">$100-200</p>',
  );
  const T = dom.window.Timeprice,
    fx = dom.window.TimepriceFX.seed;
  const value = 169.9 / fx.rates.USD;
  assert.equal(
    d.querySelector("#price").textContent,
    T.duration(value, T.estimate(T.defaults.salary).perMinute),
  );
  await change({ mode: { newValue: "work" } });
  assert.equal(
    d.querySelector("#price").textContent,
    T.duration(value, T.estimate(T.defaults.salary, "work").perMinute, "work"),
  );
  assert.match(d.querySelector("#range").textContent, /m–\d+d/);
  await change({ enabled: { newValue: false } });
  assert.equal(d.querySelector("#price").textContent, "$169.90");
  assert.equal(d.querySelector("#range").textContent, "$100-200");
  dom.window.close();
});
test("page currency metadata changes recalculate bare dollars", async () => {
  const { dom, d } = await setup(
    '<html lang="en-CA"><head><meta itemprop="priceCurrency" content="CAD"></head><body><p>$100</p></body></html>',
  );
  const T = dom.window.Timeprice,
    fx = dom.window.TimepriceFX.seed;
  assert.equal(
    d.querySelector("p").textContent,
    T.duration(100 / fx.rates.CAD, T.estimate(T.defaults.salary).perMinute),
  );
  d.querySelector("meta").setAttribute("content", "AUD");
  await settle();
  assert.equal(
    d.querySelector("p").textContent,
    T.duration(100 / fx.rates.AUD, T.estimate(T.defaults.salary).perMinute),
  );
  dom.window.close();
});
test("detached converted elements restore before being reused", async () => {
  const { dom, d } = await setup('<p id="p">10 €</p>');
  const el = d.querySelector("p");
  el.remove();
  await settle();
  assert.equal(el.textContent, "10 €");
  d.body.append(el);
  await settle();
  assert.equal(el.textContent, "2h 26m");
  dom.window.close();
});
test("new text added inside a split price does not preserve an obsolete conversion", async () => {
  const { dom, d, change } = await setup(
    '<span class="price"><b>19</b><sup>,99</sup><i>€</i></span>',
  );
  d.querySelector(".price").append(" sale");
  await settle();
  assert.ok(!d.querySelector(".price").textContent.includes("4h 51m,99"));
  await change({ enabled: { newValue: false } });
  assert.equal(d.querySelector(".price").textContent, "19,99€ sale");
  dom.window.close();
});
