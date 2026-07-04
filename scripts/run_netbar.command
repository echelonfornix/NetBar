#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "NetBar first-run helper"
echo
echo "If macOS asks for your password, it is for Apple's Xcode license command."
echo "After you accept the license, this script will build and open NetBar."
echo

sudo xcodebuild -license
./scripts/build.sh
open build/NetBar.app

echo
echo "NetBar should now be running in your Menu Bar."
