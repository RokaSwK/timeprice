# Validation

## Automated

Run `pnpm install && pnpm check && pnpm package`.

Unit tests cover Spanish reference calculations, duration boundaries, international currency formats, explicit and inferred currency codes, unsupported currencies, conversion direction, cache validation, request deduplication and offline fallback.

DOM tests verify that original elements and styles survive replacement, partial page updates use fresh values, disabling restores original text, currency changes recalculate, and salary/mode settings persist. Authored fixtures model common Apple-style inline prices, IKEA-style visible/screen-reader duplicates, and Quince-style dollar cards. Tests do not contact retailers or rate services.

## Manual Chrome checklist

Load `extension/` unpacked or extract the release ZIP. Use the public default salary.

1. Check an ordinary euro price on Apple Spain and a split product price on IKEA Spain.
2. Check dollar prices on Quince's [carry-on listing](https://www.quince.com/shop/home/travel/carryon-suitcases) and a product page.
3. Confirm text inherits site styling, comparison-price strikethrough remains, and no badges appear.
4. Switch between all-time and 40 × 52 work-hours mode without reloading. In work mode, €100 should be `7h 1m`; in all-time mode, `1d 5h 32m`.
5. Change salary, reopen the popup, and confirm persistence. Restore the default.
6. Disable the extension and verify original prices return. Re-enable it.
7. Use **Currencies & exchange rates → Refresh rates**. Check the date and displayed reference rate. Expected foreign-price time depends on the current rate.
8. Navigate or change a product variant and verify newly rendered prices convert without duplicating text.
9. Reload the extension after source updates, then refresh test tabs.

## Historical observations

Live Chrome checks on 6–7 September 2026 confirmed native replacements on Apple Spain, IKEA Spain, and Quince, plus mode switching, salary persistence, original-price restoration, and successful manual rate refresh. With the 4 September 2026 rate of 1 EUR = 1.1622 USD, Quince's $129.90 price was `7h 50m` and $169.90 was `1d 2h 15m` in work mode. These are dated observations, not current retailer-price or exchange-rate promises.
