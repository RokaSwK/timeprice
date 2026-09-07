# Privacy

Timeprice does not operate a backend, require an account, or include analytics, ads, or tracking libraries.

## On-device processing

Your salary, selected time basis, enabled state, and cached exchange-rate metadata are kept in Chrome's local extension storage. They are not synced by Timeprice. The content script reads page text and currency metadata locally to replace prices; it keeps original text in memory so it can restore it when disabled. It does not save browsing history or page contents.

## Network requests

The background worker requests public rates from:

`https://api.frankfurter.dev/v1/latest?base=EUR`

This URL is fixed. Requests omit credentials and referrers and do not include salary, prices, browsing URLs, or account information. As with any network request, the provider and its infrastructure can receive your IP address and ordinary connection/request metadata. Their own policies apply. Rates are requested on installation, browser startup, stale-cache page requests, or a manual refresh in the popup. Timeprice has no separate telemetry endpoint.

## Permissions

- `storage`: local settings and rate cache.
- Content-script matching on HTTP(S) pages: required to replace prices across websites. Chrome's extension site-access controls can limit this access.
- Host permission for `https://api.frankfurter.dev/*`: permits the background worker to fetch rates.

No clipboard, browser-history, cookie, account, or payment permissions are requested.

## Removing data

Uninstalling Timeprice removes its local extension storage through Chrome's normal extension removal process. Refresh open tabs to restore the original website rendering. Reports you submit to GitHub are governed by GitHub's policies; do not post salaries, account details, or unredacted private page captures in public issues.
