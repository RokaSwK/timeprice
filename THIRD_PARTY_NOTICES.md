# Third-party notices

The extension runtime contains project-authored JavaScript, HTML and CSS, plus a small dated numerical exchange-rate snapshot fetched from Frankfurter. The snapshot is attributed to the source in the application and documentation. Public reference data remains subject to the provider's applicable terms; the project's MIT license does not grant rights in third-party services, names or marks.

- [Frankfurter](https://frankfurter.dev/v1/): public daily exchange-rate service; source of the bundled reference snapshot in `extension/fx.js`.
- [jsdom](https://github.com/jsdom/jsdom): MIT-licensed development dependency for DOM tests.
- [Prettier](https://github.com/prettier/prettier): MIT-licensed development dependency for formatting.
- [fflate](https://github.com/101arrowz/fflate): MIT-licensed development dependency for release packaging.

These npm packages and their transitive dependencies retain their own notices in their published packages. They are not included in the extension ZIP. `pnpm-lock.yaml` records exact development dependency versions.

Apple, IKEA and Quince are third-party names used only for compatibility discussion. Test fixtures are small authored examples of markup patterns, not copies of complete retailer pages or product assets.
