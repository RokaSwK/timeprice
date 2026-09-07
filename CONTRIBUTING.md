# Contributing

Use Node.js 22 or later. Run `npm ci`, make the change, then run `npm run format`, `npm run check`, and `npm run package`.

Keep changes focused. Add a regression test for a parsing or restoration bug. Tests must be offline and independent of the current date: inject a clock when testing dated exchange-rate fixtures. Prefer minimal authored markup to scraped pages. Do not add real account data, browser profiles, credentials, or private URLs.

For a price-detection report, include the public page URL, displayed currency/format, expected behavior, and a small anonymized markup example if possible. State the extension version and time mode. Never include a personal salary; reproduce the issue with the public default or another invented value.

Preserve native website elements and event handlers. Unsupported or ambiguous prices should remain unchanged rather than silently becoming an incorrect time. Do not add analytics or transmit settings/page data to exchange-rate services.

Validate browser changes with the checklist in [docs/TESTING.md](docs/TESTING.md). A passing DOM test is not a claim of live-browser compatibility.

By contributing, you agree that your contribution is licensed under the project's MIT license.
