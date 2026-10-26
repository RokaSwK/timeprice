# Timeprice

Turn prices into time.

Timeprice is a privacy-first Chrome extension that replaces prices on shopping pages with the time it takes to earn them. It keeps the page's original typography and layout, supports 30 currencies, and can restore every changed price instantly.

## What it does

- Converts prices into either work time or total calendar time.
- Preserves the site's existing text, links, controls, and styling.
- Handles common currency formats, ranges, split-price markup, and dynamic pages.
- Converts foreign prices through daily reference rates cached on your device.
- Updates open tabs when you change salary or time mode.
- Stores settings locally and includes no analytics, account, or API key.

The editable default is **€50,981 gross per year**. Its number is a neutral public benchmark: the U.S. Bureau of Labor Statistics reported a $24.51 median hourly wage across all occupations for May 2025, which annualizes to $50,980.80 at 2,080 hours. Timeprice rounds that benchmark to 50,981; it does not claim that euros and dollars have equal value. Enter your own gross euro salary for a personal estimate.

## Install

1. Download the latest ZIP from [GitHub Releases](https://github.com/RokaSwK/timeprice/releases/latest).
2. Unzip it into a permanent folder.
3. Open `chrome://extensions`, enable **Developer mode**, and click **Load unpacked**.
4. Select the folder containing `manifest.json`, pin Timeprice, and reload open shopping tabs.

The extension is not currently in the Chrome Web Store. You can also clone this repository and load `extension/` directly; no build step is required. To update, replace the files, reload the extension from `chrome://extensions`, and refresh open shopping tabs.

## Use

Open the toolbar popup, enter your yearly gross salary in euros, choose a time basis, and save.

| Mode               | Annual time basis | A displayed day means |
| ------------------ | ----------------: | --------------------: |
| All time (default) |       8,760 hours |              24 hours |
| Work time          |       2,080 hours |       8 working hours |

Both modes use the same estimated net income and round to the nearest minute. Work time uses 40 hours per week for 52 weeks; it does not subtract holidays or leave. All time uses 365 days, including during leap years. Pause Timeprice to restore original prices.

## Currency conversion

Timeprice recognizes EUR, USD, GBP, CHF, CAD, AUD, NZD, JPY, CNY, HKD, SGD, INR, BRL, MXN, SEK, NOK, DKK, PLN, CZK, HUF, RON, TRY, ZAR, KRW, THB, IDR, MYR, PHP, ILS, and ISK.

Rates come from [Frankfurter's public reference-rate API](https://frankfurter.dev/v1/). They refresh on installation, Chrome startup, or when a page needs a stale rate. Cached and bundled rates expire after 14 days; without a valid rate, foreign prices remain unchanged. Euro prices work offline.

Currency inference is conservative. Explicit codes and qualified symbols such as `US$`, `C$`, and `A$` take priority. A bare `$` uses page metadata or region and otherwise falls back to USD. Ambiguous prices may be left unchanged.

## Income estimate

Timeprice currently estimates take-home income using an indicative 2026 Spanish employee model. It assumes an employee under 65 with permanent employment, no children, salary-only income, and no special deductions.

The model includes employee Social Security, solidarity contributions above the contribution cap, the general combined IRPF reference scale, employment expenses, the personal-minimum tax credit, and the low-income work reduction. Regional rates, special regimes, self-employment, minimum contribution bases, and personal deductions are not modeled. This is a rough comparison tool, not payroll or tax advice, and its rules do not update automatically.

Sources: [2026 Social Security rules](https://www.boe.es/eli/es/o/2026/03/30/pjc297), [AEAT income-tax manual](https://sede.agenciatributaria.gob.es/Sede/ayuda/manuales-videos-folletos/manuales-practicos/irpf-2025.html), [AEAT work-income reduction](https://sede.agenciatributaria.gob.es/Sede/ayuda/manuales-videos-folletos/manuales-ayuda-presentacion/irpf-2024/7-cumplimentacion-irpf/7_1-rendimientos-trabajo-personal/7_1_6-reduccion-obtencion-rendimientos-trabajo.html), and [BLS May 2025 national wage data](https://www.bls.gov/news.release/ocwage.t01.htm).

## Privacy and limitations

Salary, settings, and exchange-rate metadata stay in Chrome's local extension storage. Timeprice has no telemetry endpoint. Its only network request fetches public exchange rates; it does not send salary, prices, page contents, or browsing URLs. See [PRIVACY.md](PRIVACY.md).

Timeprice changes displayed text only. It cannot change checkout totals or make purchases. Chrome internal pages, the Chrome Web Store, PDFs, image or canvas text, shadow roots, and frames are outside its current coverage. Website changes can break price detection; pause the extension if a page behaves unexpectedly.

## Mac app (notch) and Safari extension

`mac/` contains a native macOS 15+ SwiftUI app that lives in the MacBook notch, plus a Safari Web Extension built from the same `extension/` files.

- **At rest**, a black pill sits flush with the notch with a live earnings ticker beside it during work hours.
- **Hover** to see what you have earned today (ticking up live), progress through the workday, this week and month, and your net hourly rate.
- **Price alerts**: when the Safari extension sees a product price on the page you are viewing, the notch briefly expands, e.g. `AirPods Pro 3 · €279.00 · 2d 0h 4m of work`.
- **Click** for a panel with Today, Prices (recently seen prices in time) and Settings (gross salary, work days and hours, work or all-time mode). A menu bar item has the same shortcuts and Quit.

The app does not maintain its own salary math. `mac/Shared/SalaryModel.swift` is a line-for-line port of `estimate()` and `duration()`, and the unit tests run `extension/core.js` in JavaScriptCore to check that the port's results are bit-identical. Earnings accrue at the work-time rate (net ÷ 2,080 h) during your scheduled hours, so the ticker agrees with work-mode prices. The time mode only changes how prices are expressed, as in the extension. On displays without a notch, the pill sits at the top centre of the screen.

### Build and run

Requires Xcode 16 or later (built with Xcode 27.1). No Apple Developer account is needed because the build is signed ad hoc.

```sh
xcodebuild -project mac/Timeprice.xcodeproj -scheme Timeprice \
  -configuration Debug -derivedDataPath mac/build build
open mac/build/Build/Products/Debug/Timeprice.app
xcodebuild -project mac/Timeprice.xcodeproj -scheme Timeprice \
  -derivedDataPath mac/build test
```

The extension target copies `extension/*.js|css|html` into the appex at build time. Only the Safari manifest and three small shims live in `mac/SafariWeb/`:

- `safari-shim.js` makes `importScripts` a no-op in Safari's non-persistent background page.
- `safari-bridge.js` reports the product price on the current page.
- `safari-background.js` forwards prices to the app and syncs `salary`, `mode` and `enabled` both ways.

Edit `extension/`, rebuild, and both browsers pick up the change.

### Enable the unsigned Safari extension

1. Launch `Timeprice.app` once so macOS registers the embedded extension.
2. In Safari, open **Settings → Advanced** and turn on **Show features for web developers**.
3. Choose **Develop → Allow Unsigned Extensions** (on recent Safari versions this is under **Settings → Developer**). Safari resets this whenever it quits.
4. In **Settings → Extensions**, enable **Timeprice** and allow it on the websites you want.

The extension's native handler and the app exchange data through `~/Library/Application Support/Timeprice/shared.json` and a local distributed notification. The sandboxed extension reaches that file through a temporary home-relative sandbox exception, which works in ad-hoc builds. A signed distribution build should switch to a Team-ID-prefixed App Group.

Hidden flags for demos: `--demo-alert` shows a sample price alert, `--open today|prices|settings|expanded` opens a state, and `--pin` keeps it open. `Timeprice --render-assets <dir> [--frames]` renders every notch state to 2x PNGs with deterministic demo data, both on a dark crop and composited over a desktop, plus before-and-after captures of `mac/Demo/product.html` in WebKit with the real extension scripts injected.

## Development

Node.js 22 or later is required. The shipped extension has no runtime package dependencies.

```sh
pnpm install
pnpm check
pnpm package
```

`pnpm check` verifies formatting and runs deterministic offline tests. `pnpm package` creates and validates an installable ZIP in `dist/`. See [docs/TESTING.md](docs/TESTING.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Timeprice is not affiliated with stores used for compatibility testing. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
