#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NetBar"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
TMP_DIR="$(mktemp -d /tmp/netbar-build.XXXXXX)"
TMP_APP_DIR="$TMP_DIR/$APP_NAME.app"
CONTENTS_DIR="$TMP_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$BUILD_DIR"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  "$ROOT/scripts/generate_icon.py"
fi

swiftc \
  -O \
  -framework AppKit \
  -framework Foundation \
  "$ROOT/Sources/NetBar/NetBar.swift" \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

xattr -cr "$TMP_APP_DIR"
codesign --force --sign "$SIGN_IDENTITY" --deep "$TMP_APP_DIR"
xattr -cr "$TMP_APP_DIR"
codesign --verify --deep --strict --verbose=2 "$TMP_APP_DIR"

ditto --noextattr --noqtn "$TMP_APP_DIR" "$APP_DIR"
xattr -cr "$APP_DIR" || true

echo "Built $APP_DIR"
echo "Signed with: $SIGN_IDENTITY"
echo "Run with: open \"$APP_DIR\""
