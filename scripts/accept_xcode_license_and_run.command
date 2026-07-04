#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "NetBar Xcode license helper"
echo
echo "This runs Apple's explicit command-line license accept step, then builds NetBar."
echo "You may be asked for your Mac password by sudo."
echo

sudo xcodebuild -license accept
./scripts/build.sh
open build/NetBar.app

echo
echo "NetBar should now be running in your Menu Bar."
