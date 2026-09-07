# Timeprice

**See what a purchase costs in your time.** A small Chrome extension that replaces prices directly in a website’s own font, color, and layout—no extra badges.

Enter your yearly gross salary in euros. Timeprice estimates Spanish take-home pay, converts foreign prices to euros, and displays the time needed to earn that amount.

| Example | Work-hours mode | All-time mode |
| ------- | --------------- | ------------- |
| €19.99  | `1h 24m`        | `5h 54m`      |
| €100    | `7h 1m`         | `1d 5h 32m`   |

Examples use the **€40,000 gross/year default**, with an indicative €29,655 net/year estimate. This default is an editable example, not a requirement.

## Features

- Replaces existing price text while retaining website styling, links, and controls.
- Two time bases: **40 hours × 52 weeks** or **365 days × 24 hours**.
- Compact `Xd Yh Zm` display, omitting zero days.
- Converts 30 supported currencies using cached daily exchange rates.
- Handles common split-price markup, price ranges, and dynamically updated pages.
- Toggle off to restore the original prices. Changes to salary and time basis apply to open tabs.
- Salary stored locally. No analytics, account, or API key.

## Install in Chrome

1. Download `timeprice-v1.1.1.zip` from [Releases](https://github.com/RokaSwK/timeprice/releases/latest) and unzip it into a permanent folder.
2. Open `chrome://extensions` and enable **Developer mode**.
3. Click **Load unpacked** and select the unzipped folder containing `manifest.json`.
4. Pin **Timeprice** using Chrome’s Extensions menu.
5. Reload any shopping tabs that were already open.

Alternatively, clone this repository and load its `extension/` folder. **No build or npm installation is needed to use the extension.** It is not currently published in the Chrome Web Store.

Keep the installed folder in place. To update, replace its files with the new release, open the Timeprice popup, expand **How the estimate works**, click **Reload local extension**, and reload your shopping tabs. You can also use Reload on the extension’s card in `chrome://extensions`.

## Settings

Open the toolbar popup to set your salary or pause replacements.

| Actual work hours | Annual denominator     | Meaning of `d` |
| ----------------- | ---------------------- | -------------- |
| On                | 2,080 hours (40 × 52)  | 8-hour workday |
| Off (default)     | 8,760 hours (365 × 24) | 24-hour day    |

Both modes use the same net income estimate and round to the nearest minute. Sub-minute positive amounts may show `0h 0m`. All-time mode uses 365 days even in leap years. Work mode assumes 260 eight-hour workdays, without subtracting holidays or leave.

## Currency conversion

Supported codes:

```text
EUR USD GBP CHF CAD AUD NZD JPY CNY HKD SGD INR BRL MXN
SEK NOK DKK PLN CZK HUF RON TRY ZAR KRW THB IDR MYR PHP ILS ISK
```

Explicit codes and symbols such as `US$`, `C$`, `A$`, `NZ$`, `HK$`, `S$`, `R$`, `£`, `¥`, and `₹` are recognized. Bare `$` follows currency metadata or the page’s region, falling back to **USD**. Bare `¥` defaults to **JPY**, or CNY on Chinese pages. Ambiguous `kr` requires Nordic currency context. Region inference is a heuristic; use caution on sites with ambiguous currency displays.

Rates come from [Frankfurter’s daily reference-rate API](https://frankfurter.dev/v1/). The extension divides the foreign amount by the quoted currency units per EUR, then converts euros to time. These are reference rates, not a bank’s or merchant’s final rates; fees are excluded.

Rates refresh on installation, browser startup, or a page request when the cache is over 24 hours old. The popup shows the rate date and provides **Refresh rates**. Failed automatic requests retry at most hourly. A dated bundled snapshot provides an offline fallback; all cached or bundled rates expire after 14 days. Without a valid rate, foreign prices stay unchanged. Euro prices work offline indefinitely.

## Spanish tax estimate

This is an **indicative 2026 employee-income estimate**, not a payslip or tax-return calculator. Spain has regional tax differences; there is no universal resident tax rate.

The model assumes an employee under 65, permanent employment, no children, salary only, and no special deductions. It applies:

- Employee Social Security of 6.50%, capped at an annual contribution base of €61,214.40, plus employee solidarity contributions above the cap.
- A general combined IRPF reference scale of 19%, 24%, 30%, 37%, 45%, and 47%.
- €2,000 employment expenses, the €5,550 personal-minimum tax credit, and the low-income work reduction.

Regional rates, additional deductions, minimum contribution bases, special regimes, and self-employment are not modeled. Rules are not automatically updated each tax year.

Sources: [2026 Social Security rules](https://www.boe.es/eli/es/o/2026/03/30/pjc297), [AEAT income-tax manual](https://sede.agenciatributaria.gob.es/Sede/ayuda/manuales-videos-folletos/manuales-practicos/irpf-2025.html), and [AEAT work-income reduction](https://sede.agenciatributaria.gob.es/Sede/ayuda/manuales-videos-folletos/manuales-ayuda-presentacion/irpf-2024/7-cumplimentacion-irpf/7_1-rendimientos-trabajo-personal/7_1_6-reduccion-obtencion-rendimientos-trabajo.html).

## Privacy and permissions

`storage` saves settings and exchange rates on the device. Content scripts run on HTTP(S) pages to find and replace prices. The only extension-initiated network request fetches public rates from `api.frankfurter.dev`; salary, prices, and browsing URLs are not sent. See [PRIVACY.md](PRIVACY.md) for details.

## Compatibility and limitations

Manually tested in Chrome on Apple Spain, IKEA Spain, and Quince listing/product pages in September 2026. Website changes can affect compatibility; this is not a guarantee for every site.

Chrome internal pages, the Chrome Web Store, PDFs, image/canvas text, shadow roots, and frames are outside this version’s coverage. Bare numbers without a currency marker are left unchanged. Some locale-specific formats and ambiguous symbols are unsupported. Original `aria-label` attributes may still contain money even when visible text is replaced. Prices may briefly appear before the script runs. Long conversions can wrap within a site’s existing layout.

The extension changes displayed text only; it does not change checkout amounts, make purchases, or invoke commerce actions. Pause it if a website behaves unexpectedly. If an update or extension reload leaves old time text visible, refresh that tab.

## Development

Requires Node.js 22 or later. There are no bundled runtime dependencies.

```sh
npm ci
npm run check
npm run package
```

`npm run check` verifies formatting and runs deterministic offline unit/DOM tests. `npm run package` creates an installable ZIP in `dist/` and checks its contents. `npm run format` formats source files. CI runs on Node.js 22 and 24.

Tests cover salary calculations, both time bases, currency parsing and conversion direction, cache expiry and failure, dynamic updates, exact restoration, and persisted settings. Small **authored** fixtures model storefront markup; no downloaded storefront documents, customer data, or remote scripts are distributed. Manual browser checks are documented in [docs/TESTING.md](docs/TESTING.md).

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Store and product names are mentioned only to describe compatibility; this project is not affiliated with those retailers. Third-party dependencies and exchange-rate sources retain their own licenses and terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
