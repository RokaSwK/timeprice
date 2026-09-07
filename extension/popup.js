const $ = (id) => document.getElementById(id);
const euro = (value, digits = 2) =>
  new Intl.NumberFormat("en-IE", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value);
let mode = "all";
function render(salary) {
  const e = Timeprice.estimate(salary, mode);
  $("minute").textContent = euro(e.perMinute, 4);
  $("rhythm").textContent =
    `${euro(e.perHour)} / hour  ·  ${euro(e.perDay)} / ${mode === "work" ? "8-hour workday" : "day"}`;
  $("net").textContent = euro(e.net);
  $("social").textContent = euro(e.social);
  $("irpf").textContent = euro(e.irpf);
  $("example").textContent = Timeprice.duration(100, e.perMinute, mode);
  $("basis").textContent =
    mode === "work" ? "EVERY HOUR YOU WORK" : "EVERY MINUTE OF YOUR YEAR";
  $("explain").textContent =
    mode === "work"
      ? "Your net salary ÷ 2,080 work hours per year. One workday means 8 hours; 260 workdays per year."
      : "Your net salary ÷ 365 days ÷ 24 hours ÷ 60 minutes. Every minute counts, even when you’re asleep.";
}
chrome.storage.local.get(Timeprice.defaults).then((s) => {
  mode = s.mode === "work" ? "work" : "all";
  $("work-mode").checked = mode === "work";
  $("salary").value = s.salary;
  $("enabled").checked = s.enabled;
  render(Number(s.salary));
});
$("settings").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const salary = Number($("salary").value);
    Timeprice.estimate(salary, mode);
    await chrome.storage.local.set({ salary });
    render(salary);
    $("status").textContent = "Saved. Prices update automatically.";
  } catch (error) {
    $("status").textContent = error.message;
  }
});
$("enabled").addEventListener("change", async () => {
  try {
    await chrome.storage.local.set({ enabled: $("enabled").checked });
    $("status").textContent = $("enabled").checked
      ? "Time conversions are on."
      : "Time conversions are paused.";
  } catch {
    $("status").textContent = "Could not save. Please try again.";
  }
});

$("reload-extension").addEventListener("click", () => chrome.runtime.reload());

$("work-mode").addEventListener("change", async () => {
  try {
    mode = $("work-mode").checked ? "work" : "all";
    await chrome.storage.local.set({ mode });
    const saved = await chrome.storage.local.get(Timeprice.defaults);
    render(Number(saved.salary));
    $("status").textContent = "Time basis saved. Prices update automatically.";
  } catch {
    $("status").textContent = "Could not save. Please try again.";
  }
});

async function showRates() {
  const saved = await chrome.storage.local.get({ fx: null, fxError: null });
  const fx = globalThis.TimepriceFX?.available(saved.fx);
  $("fx-status").textContent = fx
    ? `Rates dated ${fx.date} · 1 EUR = ${fx.rates.USD} USD${saved.fxError ? " · offline cache" : ""}`
    : "Exchange rates unavailable or expired. Only euro prices convert.";
}
$("refresh-rates").addEventListener("click", async () => {
  $("refresh-rates").disabled = true;
  $("fx-status").textContent = "Updating exchange rates…";
  try {
    await chrome.runtime.sendMessage({ type: "refresh-rates", force: true });
    await showRates();
  } catch {
    $("fx-status").textContent =
      "Could not refresh. Reload the local extension and try again.";
  } finally {
    $("refresh-rates").disabled = false;
  }
});
showRates();
