(() => {
  "use strict";
  if (globalThis.__timepriceLoaded) return;
  globalThis.__timepriceLoaded = true;
  let settings = { ...Timeprice.defaults };
  let rate = Timeprice.estimate(settings.salary, settings.mode).perMinute;
  // Change existing text nodes only: site fonts, elements, links and handlers survive.
  const skip =
    'script,style,noscript,textarea,input,select,option,svg,canvas,pre,code,[contenteditable]:not([contenteditable="false"]),[role="textbox"]';
  const groups = new Set();
  let timer;
  let fx = null,
    currencyDirty = false,
    pageCurrency = "USD",
    fxDate = null;
  const observer = new MutationObserver((records) => {
    if (records.some((r) => r.type === "attributes")) currencyDirty = true;
    schedule();
  });
  function readPageCurrency() {
    const region = (
      document.documentElement.lang.split("-")[1] ||
      location.hostname.split(".").pop()
    ).toUpperCase();
    const regional = {
      US: "USD",
      CA: "CAD",
      AU: "AUD",
      NZ: "NZD",
      SG: "SGD",
      HK: "HKD",
      MX: "MXN",
      BR: "BRL",
      JP: "JPY",
      CN: "CNY",
      SE: "SEK",
      NO: "NOK",
      DK: "DKK",
      IS: "ISK",
      AR: "ARS",
      CL: "CLP",
      TW: "TWD",
    };
    const codes = [
      ...document.querySelectorAll(
        'meta[itemprop="priceCurrency"],meta[property="product:price:currency"],meta[property="og:price:currency"]',
      ),
    ]
      .map((m) => m.content?.toUpperCase())
      .filter(Boolean);
    return new Set(codes).size === 1 ? codes[0] : regional[region] || "USD";
  }
  function contextFor(el) {
    const local = el.closest("[data-currency],[itemscope]");
    const meta = local?.querySelector('[itemprop="priceCurrency"]');
    const declared =
      local?.getAttribute("data-currency") ||
      meta?.getAttribute("content") ||
      meta?.textContent;
    const currency = (declared || pageCurrency).trim().toUpperCase();
    return {
      currency,
      dollar: [
        "USD",
        "CAD",
        "AUD",
        "NZD",
        "SGD",
        "HKD",
        "MXN",
        "ARS",
        "CLP",
        "TWD",
      ].includes(currency)
        ? currency
        : "USD",
      yen: currency === "CNY" ? "CNY" : "JPY",
    };
  }
  const findPrices = (text, el) => Timeprice.prices(text, contextFor(el));
  function convert(match) {
    const usable = globalThis.TimepriceFX?.available(fx);
    const value = Timeprice.toEuros(match.value, match.currency, usable);
    if (value === null) return null;
    const first = Timeprice.duration(value, rate, settings.mode);
    const end =
      match.valueEnd === undefined
        ? null
        : Timeprice.toEuros(match.valueEnd, match.currency, usable);
    return end === null
      ? first
      : first + "–" + Timeprice.duration(end, rate, settings.mode);
  }
  function textNodes(el) {
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, {
      acceptNode: (n) =>
        n.parentElement.closest(skip)
          ? NodeFilter.FILTER_REJECT
          : NodeFilter.FILTER_ACCEPT,
    });
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    return nodes;
  }
  function restore(group) {
    for (const part of group.parts)
      if (part.node.data === part.rendered) part.node.data = part.original;
  }
  function reset() {
    for (const group of groups) restore(group);
    groups.clear();
  }
  function replaceGroup(el, nodes, replacement) {
    if (!nodes.length) return;
    const parts = nodes.map((node, i) => ({
      node,
      original: node.data,
      rendered: i === 0 ? replacement : "",
    }));
    for (const p of parts) p.node.data = p.rendered;
    groups.add({ el, parts, renderedText: el.textContent });
  }
  function scan() {
    timer = null;
    observer.disconnect();
    try {
      const availableDate = globalThis.TimepriceFX?.available(fx)?.date || null;
      if (availableDate !== fxDate) {
        reset();
        fxDate = availableDate;
      }
      const latestCurrency = readPageCurrency();
      if (currencyDirty || latestCurrency !== pageCurrency) {
        reset();
        currencyDirty = false;
      }
      pageCurrency = latestCurrency;
      for (const group of groups) {
        if (
          !group.el.isConnected ||
          (group.renderedText !== undefined &&
            group.el.textContent !== group.renderedText) ||
          group.parts.some(
            (p) => !p.node.isConnected || p.node.data !== p.rendered,
          )
        ) {
          restore(group);
          groups.delete(group);
        }
      }
      if (!settings.enabled) {
        reset();
        return;
      }
      const protectedNodes = new Set(
        [...groups].flatMap((g) => g.parts.map((p) => p.node)),
      );
      const candidates = document.querySelectorAll(
        '.a-price,[data-skapa^="price@"],[itemprop="price"],[class*="price" i]',
      );
      for (const el of candidates) {
        if (
          el.closest(skip) ||
          !el.children.length ||
          el.textContent.length > 150
        )
          continue;
        const nodes = textNodes(el);
        if (nodes.some((n) => protectedNodes.has(n))) continue;
        // IKEA and Amazon provide separate visible and screen-reader copies.
        const copies = el.matches('[data-skapa^="price@"]')
          ? [...el.children]
          : el.matches(".a-price")
            ? [...el.children]
            : null;
        if (copies) {
          const source = el.matches(".a-price")
            ? el.querySelector(".a-offscreen")
            : el.querySelector(':scope > [aria-hidden="true"]');
          const match = source && findPrices(source.textContent.trim(), el);
          if (
            !match ||
            match.length !== 1 ||
            match[0].original.trim() !== source.textContent.trim() ||
            convert(match[0]) === null
          )
            continue;
          for (const copy of copies) {
            const ns = textNodes(copy);
            if (!ns.length) continue;
            // Use first non-whitespace text so indentation does not receive the price.
            const first = ns.findIndex((n) => n.data.trim());
            if (first < 0) continue;
            replaceGroup(copy, ns.slice(first), convert(match[0]));
            ns.forEach((n) => protectedNodes.add(n));
          }
          continue;
        }
        const text = el.textContent.trim(),
          matches = findPrices(text, el);
        if (
          matches.length !== 1 ||
          matches[0].original.trim() !== text ||
          convert(matches[0]) === null
        )
          continue;
        const first = nodes.findIndex((n) => n.data.trim());
        if (first < 0) continue;
        replaceGroup(el, nodes.slice(first), convert(matches[0]));
        nodes.forEach((n) => protectedNodes.add(n));
      }
      for (const node of textNodes(document.body)) {
        if (protectedNodes.has(node) || !/[0-9]/.test(node.data)) continue;
        const matches = findPrices(node.data, node.parentElement);
        if (!matches.length) continue;
        const original = node.data;
        let rendered = "",
          end = 0;
        for (const m of matches) {
          rendered += original.slice(end, m.index) + (convert(m) ?? m.original);
          end = m.index + m.length;
        }
        rendered += original.slice(end);
        if (rendered === original) continue;
        node.data = rendered;
        groups.add({
          el: node.parentElement,
          parts: [{ node, original, rendered }],
        });
      }
    } finally {
      observer.observe(document.documentElement, {
        subtree: true,
        childList: true,
        characterData: true,
        attributes: true,
        attributeFilter: ["content", "data-currency", "lang"],
      });
    }
  }
  function schedule() {
    if (!timer) timer = setTimeout(scan, 180);
  }
  chrome.storage.local
    .get({ ...Timeprice.defaults, fx: null })
    .then((saved) => {
      fx = saved.fx;
      settings = saved;
      try {
        rate = Timeprice.estimate(Number(saved.salary), saved.mode).perMinute;
      } catch {}
      scan();
    });
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area !== "local") return;
    if (changes.fx) fx = changes.fx.newValue;
    if (!["salary", "enabled", "mode", "fx"].some((k) => changes[k])) return;
    if (changes.salary)
      settings.salary = changes.salary.newValue || Timeprice.defaults.salary;
    if (changes.enabled) settings.enabled = changes.enabled.newValue !== false;
    if (changes.mode)
      settings.mode = changes.mode.newValue === "work" ? "work" : "all";
    try {
      rate = Timeprice.estimate(
        Number(settings.salary),
        settings.mode,
      ).perMinute;
    } catch {
      return;
    }
    observer.disconnect();
    reset();
    scan();
  });
  // One request for public rates; no page URL, price or salary is sent.
  chrome.runtime?.sendMessage({ type: "refresh-rates" }).catch(() => {});
})();
