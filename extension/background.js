importScripts("fx.js");
let inFlight;
async function refresh(force = false) {
  const saved = await chrome.storage.local.get([
    "fx",
    "fxCheckedAt",
    "fxAttemptAt",
  ]);
  if (
    !force &&
    TimepriceFX.valid(saved.fx) &&
    Date.now() - (saved.fxCheckedAt || 0) < 86400000
  )
    return saved.fx;
  if (!force && Date.now() - (saved.fxAttemptAt || 0) < 3600000)
    return TimepriceFX.available(saved.fx);
  await chrome.storage.local.set({ fxAttemptAt: Date.now() });
  try {
    const response = await fetch(
      "https://api.frankfurter.dev/v1/latest?base=EUR",
      {
        credentials: "omit",
        referrerPolicy: "no-referrer",
        signal: AbortSignal.timeout(12000),
      },
    );
    if (!response.ok) throw new Error("Exchange-rate service unavailable");
    const fx = await response.json();
    if (!TimepriceFX.valid(fx))
      throw new Error("Invalid or outdated exchange rates");
    await chrome.storage.local.set({
      fx,
      fxCheckedAt: Date.now(),
      fxError: null,
    });
    return fx;
  } catch (error) {
    await chrome.storage.local.set({ fxError: error.message });
    return TimepriceFX.available(saved.fx);
  }
}
function getRates(force = false) {
  if (!inFlight)
    inFlight = refresh(force).finally(() => {
      inFlight = null;
    });
  return inFlight;
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message?.type !== "refresh-rates") return;
  // Only the extension popup may force a refresh; page scripts cannot choose a URL.
  const force =
    message.force === true && sender.url?.startsWith(chrome.runtime.getURL(""));
  getRates(force)
    .then((fx) => respond({ ok: !!fx, date: fx?.date }))
    .catch(() => respond({ ok: false }));
  return true;
});
chrome.runtime.onInstalled.addListener(() => {
  getRates();
});
chrome.runtime.onStartup.addListener(() => {
  getRates();
});
