// Safari-only additions to the shared background.js: forward prices seen by
// safari-bridge.js to the Timeprice app and keep salary settings in sync with
// it. Messages go to the app's SafariWebExtensionHandler, never the network.
(() => {
  "use strict";
  const api = globalThis.browser ?? globalThis.chrome;
  const keys = ["salary", "mode", "enabled"];
  let lastSynced = null;
  const same = (a, b) => !!a && !!b && keys.every((k) => a[k] === b[k]);
  const native = (message) =>
    api.runtime.sendNativeMessage("com.rokaswk.timeprice", message);

  async function pull() {
    try {
      const reply = await native({ type: "get-settings" });
      const remote = reply?.settings;
      if (!remote || !(remote.updatedAt > 0)) return push();
      const local = await api.storage.local.get({
        ...Timeprice.defaults,
        settingsUpdatedAt: 0,
      });
      if (remote.updatedAt > local.settingsUpdatedAt && !same(remote, local)) {
        lastSynced = remote;
        await api.storage.local.set({
          salary: remote.salary,
          mode: remote.mode === "work" ? "work" : "all",
          enabled: remote.enabled !== false,
          settingsUpdatedAt: remote.updatedAt,
        });
      } else if (local.settingsUpdatedAt > remote.updatedAt) {
        await push();
      }
    } catch {
      // The app is not installed or not reachable; the extension works alone.
    }
  }

  async function push() {
    const local = await api.storage.local.get({
      ...Timeprice.defaults,
      settingsUpdatedAt: 0,
    });
    if (same(local, lastSynced)) return;
    lastSynced = local;
    await native({
      type: "set-settings",
      salary: Number(local.salary),
      mode: local.mode,
      enabled: local.enabled,
      updatedAt: local.settingsUpdatedAt || Date.now() / 1000,
    }).catch(() => {});
  }

  api.storage.onChanged.addListener((changes, area) => {
    if (area !== "local" || !keys.some((k) => changes[k])) return;
    if (changes.settingsUpdatedAt) return; // Applied from the app.
    api.storage.local
      .set({ settingsUpdatedAt: Date.now() / 1000 })
      .then(push)
      .catch(() => {});
  });

  api.runtime.onMessage.addListener((message, sender) => {
    if (!sender.tab) return;
    if (message?.type === "timeprice-sync") pull();
    if (message?.type === "timeprice-price-seen") {
      const { title, host, original, amount, currency, euros } = message;
      if (typeof title !== "string" || !Number.isFinite(euros)) return;
      native({
        type: "price-seen",
        title: title.slice(0, 120),
        host: String(host).slice(0, 80),
        original: String(original).slice(0, 40),
        amount: Number(amount),
        currency: String(currency),
        euros,
      }).catch(() => {});
    }
  });

  api.runtime.onStartup?.addListener(pull);
  api.runtime.onInstalled?.addListener(pull);
})();
