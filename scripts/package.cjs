const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { zipSync, unzipSync, strToU8 } = require("fflate");
const manifest = JSON.parse(fs.readFileSync("extension/manifest.json", "utf8"));
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
assert.equal(
  manifest.version,
  pkg.version,
  "Package and extension versions must match",
);
const files = {};
for (const file of fs.readdirSync("extension").sort()) {
  assert.match(
    file,
    /^[a-z-]+\.(js|html|css|json)$/,
    "Only explicit extension source files may be packaged",
  );
  const data = fs.readFileSync(path.join("extension", file));
  files[file] = [data, { mtime: new Date("2026-01-01T00:00:00Z") }];
}
files.LICENSE = [
  strToU8(fs.readFileSync("LICENSE", "utf8")),
  { mtime: new Date("2026-01-01T00:00:00Z") },
];
const zip = zipSync(files, { level: 9 });
const unpacked = unzipSync(zip);
const referenced = [
  manifest.action.default_popup,
  manifest.background.service_worker,
  ...manifest.content_scripts.flatMap((s) => [...s.js, ...s.css]),
];
for (const file of referenced)
  assert.ok(unpacked[file], `Missing packaged file: ${file}`);
assert.equal(Object.keys(unpacked).length, Object.keys(files).length);
fs.mkdirSync("dist", { recursive: true });
const output = `dist/timeprice-v${manifest.version}.zip`;
fs.writeFileSync(output, zip);
console.log(
  `Validated ${output} (${zip.length} bytes, ${Object.keys(files).length} files)`,
);
