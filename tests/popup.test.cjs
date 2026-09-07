const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { JSDOM } = require("jsdom");
test("popup loads defaults, persists salary and pause, survives reopening", async () => {
  const saved = {};
  async function open() {
    const dom = new JSDOM(fs.readFileSync("extension/popup.html", "utf8"), {
      runScripts: "outside-only",
    });
    dom.window.chrome = {
      storage: {
        local: {
          get: async (d) => ({ ...d, ...saved }),
          set: async (v) => Object.assign(saved, v),
        },
      },
    };
    dom.window.eval(fs.readFileSync("extension/core.js", "utf8"));
    dom.window.eval(fs.readFileSync("extension/popup.js", "utf8"));
    await new Promise((r) => setImmediate(r));
    return dom;
  }
  let dom = await open(),
    d = dom.window.document;
  assert.equal(d.getElementById("salary").value, "40000");
  assert.equal(d.getElementById("net").textContent, "€29,655.00");
  d.getElementById("salary").value = "60000";
  d.getElementById("settings").dispatchEvent(
    new dom.window.Event("submit", { cancelable: true }),
  );
  await new Promise((r) => setImmediate(r));
  assert.equal(saved.salary, 60000);
  d.getElementById("work-mode").checked = true;
  d.getElementById("work-mode").dispatchEvent(new dom.window.Event("change"));
  await new Promise((r) => setImmediate(r));
  assert.equal(saved.mode, "work");
  assert.match(d.getElementById("rhythm").textContent, /8-hour workday/);
  d.getElementById("enabled").checked = false;
  d.getElementById("enabled").dispatchEvent(new dom.window.Event("change"));
  await new Promise((r) => setImmediate(r));
  assert.equal(saved.enabled, false);
  dom.window.close();
  dom = await open();
  d = dom.window.document;
  assert.equal(d.getElementById("salary").value, "60000");
  assert.equal(d.getElementById("enabled").checked, false);
  assert.equal(d.getElementById("work-mode").checked, true);
  dom.window.close();
});
