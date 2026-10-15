#!/bin/zsh
# Builds dist/Blockout.app (universal release binary, Info.plist, icon) and signs it.
# Usage: build.sh [--install] [--release]
#   --install  copy the app to /Applications
#   --release  refuse to build without the signing identity (used by build-dmg.sh)
set -euo pipefail

INSTALL=false
RELEASE=false
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=true ;;
    --release) RELEASE=true ;;
    *) print -u2 "Unknown option: $arg"; exit 1 ;;
  esac
done

# A stable identity keeps the Calendar permission across rebuilds; ad hoc ("-") otherwise
IDENTITY="${BLOCKOUT_SIGN_IDENTITY:-Blockout Self-Signed}"
if ! security find-identity -p codesigning | grep -qF "\"$IDENTITY\""; then
  if $RELEASE; then
    print -u2 "Signing identity not found: $IDENTITY. Releases must be signed with it so installed copies accept the update."
    exit 1
  fi
  print -u2 "Signing identity not found: $IDENTITY (signing ad hoc; Calendar permission resets on every build)"
  IDENTITY="-"
fi

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Blockout.app"
cd "$ROOT"

BUILD_ARGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_ARGS[@]}"
BIN="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/Blockout"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# qlmanage sometimes does not exit after rendering, so wait for the PNG instead of the process
qlmanage -t -s 1024 -o "$tmp" Resources/AppIcon.svg > /dev/null 2>&1 &
png="$tmp/AppIcon.svg.png"
for _ in {1..60}; do
  [[ -s "$png" ]] && break
  sleep 0.5
done
[[ -s "$png" ]] || { print -u2 "Icon rendering failed"; exit 1; }
sleep 0.5

iconset="$tmp/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$png" --out "$iconset/icon_${size}x${size}.png" > /dev/null
  sips -z $((size * 2)) $((size * 2)) "$png" --out "$iconset/icon_${size}x${size}@2x.png" > /dev/null
done

# Calendar access needs its own entitlement under the hardened runtime
entitlements="$tmp/Blockout.entitlements"
cat > "$entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.personal-information.calendars</key><true/>
</dict>
</plist>
PLIST

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Blockout"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$(tr -d '[:space:]' < VERSION)" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(git rev-list --count HEAD 2>/dev/null || print 1)" "$APP/Contents/Info.plist"
iconutil -c icns "$iconset" -o "$APP/Contents/Resources/AppIcon.icns"
# Template image for the menu bar item, loaded by MenuBarIcon
cp Resources/MenuBarIcon.svg "$APP/Contents/Resources/MenuBarIcon.svg"
codesign --force --options runtime --entitlements "$entitlements" --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
print -u2 "Signed with: $IDENTITY"

if $INSTALL; then
  if pgrep -xq Blockout; then
    osascript -e 'tell application "Blockout" to quit' || true
    sleep 1
  fi
  rm -rf /Applications/Blockout.app
  ditto "$APP" /Applications/Blockout.app
  APP=/Applications/Blockout.app
fi
print -r -- "$APP"
