#!/bin/sh
# Xcode build phase for the Safari extension target. Copies the shared
# extension sources from ../extension unchanged, then the Safari-only manifest
# and shims from SafariWeb/. Nothing is forked: edit extension/ and rebuild.
set -eu
src="${SRCROOT}/../extension"
web="${SRCROOT}/SafariWeb"
dest="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$dest"
for file in fx.js core.js content.js content.css background.js popup.html popup.css popup.js; do
  cp "$src/$file" "$dest/$file"
done
cp "$web"/manifest.json "$web"/*.js "$dest/"
echo "Copied Timeprice web extension into $dest"
