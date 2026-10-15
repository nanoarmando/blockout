#!/bin/zsh
# Packages a release: builds and signs dist/Blockout.app with build.sh --release (universal, hardened runtime,
# "Blockout Self-Signed" required) and creates dist/Blockout-<version>.dmg with the app and an Applications link,
# ready for `gh release create v<version>`.
# Usage: build-dmg.sh <version>   (must match the VERSION file)
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
if [[ $# -ne 1 || "$1" != "$VERSION" ]]; then
  print -u2 "Usage: Scripts/build-dmg.sh <version>; the version must match the VERSION file ($VERSION)."
  exit 1
fi

"$ROOT/Scripts/build.sh" --release
APP="$ROOT/dist/Blockout.app"

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
ditto "$APP" "$staging/Blockout.app"
ln -s /Applications "$staging/Applications"

DMG="$ROOT/dist/Blockout-$VERSION.dmg"
rm -f "$DMG"
# hdiutil create is deprecated and on newer macOS produces images hdiutil itself rejects; prefer diskutil image
if diskutil image create from --help > /dev/null 2>&1; then
  diskutil image create from --format UDZO --volumeName "Blockout $VERSION" "$staging" "$DMG" > /dev/null
else
  hdiutil create -volname "Blockout $VERSION" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$DMG" > /dev/null
fi
# Never ship an image that installed copies (which mount it with hdiutil or diskutil) cannot open
if ! hdiutil verify "$DMG" > /dev/null 2>&1; then
  rm -f "$DMG"
  print -u2 "The disk image failed verification; run the script again."
  exit 1
fi
print -r -- "$DMG"
