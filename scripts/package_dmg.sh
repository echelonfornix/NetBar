#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="NetBar"
APP_DIR="$ROOT/build/$APP_NAME.app"
DIST_DIR="$ROOT/dist"
STAGING_DIR="$(mktemp -d /tmp/netbar-dmg-staging.XXXXXX)"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_DIR" ]]; then
  "$ROOT/scripts/build.sh"
fi

mkdir -p "$STAGING_DIR" "$DIST_DIR"

xattr -cr "$APP_DIR"
ditto --noextattr --noqtn "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
xattr -cr "$STAGING_DIR"
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/$APP_NAME.app"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

xattr -cr "$APP_DIR"

echo "Created $DMG_PATH"
