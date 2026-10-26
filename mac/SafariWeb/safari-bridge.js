// Safari-only content script. Runs after core.js/content.js and reports the
// main product price of the page you are viewing to the Timeprice app, which
// shows it in the notch. Only the product name, shop host and price are sent,
// and only to the local app.
(() => {
  "use strict";
  if (globalThis.__timepriceBridge) return;
  globalThis.__timepriceBridge = true;
  const api = globalThis.browser ?? globalThis.chrome;
  const meta = (name) =>
    document
      .querySelector(`meta[property="${name}"],meta[name="${name}"]`)
      ?.getAttribute("content");

  function fromJsonLd() {
    const found = [];
    const visit = (node) => {
      if (!node || typeof node !== "object") return;
      if (Array.isArray(node)) return node.forEach(visit);
      const type = [].concat(node["@type"] || []);
      if (type.includes("Product")) found.push(node);
      if (node["@graph"]) visit(node["@graph"]);
    };
    for (const script of document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      try {
        visit(JSON.parse(script.textContent));
      } catch {}
    }
    for (const product of found) {
      const offer = [].concat(product.offers || [])[0] || {};
      const price = offer.price ?? offer.lowPrice;
      if (price !== undefined)
        return {
          title: product.name,
          amount: price,
          currency: offer.priceCurrency,
        };
    }
    return null;
  }

  function product() {
    const ld = fromJsonLd();
    const amount =
      ld?.amount ??
      meta("product:price:amount") ??
      meta("og:price:amount") ??
      document.querySelector('[itemprop="price"][content]')?.content;
    const currency =
      ld?.currency ??
      meta("product:price:currency") ??
      meta("og:price:currency") ??
      document.querySelector('[itemprop="priceCurrency"]')?.content;
    if (amount === undefined || !currency) return null;
    const value =
      typeof amount === "number"
        ? amount
        : /^\d+(\.\d+)?$/.test(String(amount).trim())
          ? Number(amount)
          : Timeprice.parseAmount(String(amount));
    const code = String(currency).trim().toUpperCase();
    if (!Number.isFinite(value) || !Timeprice.currencies.includes(code))
      return null;
    const title = (
      ld?.title ||
      meta("og:title") ||
      document.querySelector("h1")?.textContent ||
      document.title
    )
      .replace(/\s+/g, " ")
      .trim();
    return { title, value, currency: code };
  }

  let sent = "";
  async function report() {
    if (document.visibilityState !== "visible") return;
    const found = product();
    if (!found) return;
    const saved = await api.storage.local.get({ enabled: true, fx: null });
    if (saved.enabled === false) return;
    const euros = Timeprice.toEuros(
      found.value,
      found.currency,
      TimepriceFX.available(saved.fx),
    );
    if (euros === null) return;
    const key = `${location.pathname}|${found.title}|${found.value}`;
    if (key === sent) return;
    sent = key;
    let original;
    try {
      original = new Intl.NumberFormat("en-IE", {
        style: "currency",
        currency: found.currency,
      }).format(found.value);
    } catch {
      original = `${found.value} ${found.currency}`;
    }
    api.runtime
      .sendMessage({
        type: "timeprice-price-seen",
        title: found.title,
        host: location.hostname.replace(/^www\./, ""),
        original,
        amount: found.value,
        currency: found.currency,
        euros,
      })
      .catch(() => {});
  }

  api.runtime.sendMessage({ type: "timeprice-sync" }).catch(() => {});
  report();
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
      sent = "";
      report();
    }
  });
  // Single-page shops change product without a page load.
  let path = location.pathname;
  setInterval(() => {
    if (location.pathname !== path) {
      path = location.pathname;
      setTimeout(report, 800);
    }
  }, 1000);
})();
