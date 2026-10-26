// Safari runs MV3 background scripts as a non-persistent page, where
// importScripts() does not exist. The manifest loads fx.js before
// background.js, so the shared background.js can call it as a no-op.
if (typeof globalThis.importScripts !== "function")
  globalThis.importScripts = () => {};
