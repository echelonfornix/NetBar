# Install Guide

## Install From a DMG

1. Open `NetBar.dmg`.
2. Drag `NetBar.app` into Applications.
3. Launch NetBar from Applications.
4. Look for the network symbol in the macOS Menu Bar.

If macOS blocks the app, open System Settings, go to Privacy & Security, and approve the app there.

## Build Locally

Install Xcode Command Line Tools if needed:

```sh
xcode-select --install
```

Accept the Xcode licence if Swift asks for it:

```sh
sudo xcodebuild -license
```

Build:

```sh
./scripts/build.sh
```

Run:

```sh
open build/NetBar.app
```

## Package Locally

```sh
./scripts/package_dmg.sh
```

The DMG is written to:

```text
dist/NetBar.dmg
```

## Launch at Login

Open NetBar settings and enable Launch at Login.

NetBar stores its LaunchAgent at:

```text
~/Library/LaunchAgents/local.netbar.status.login.plist
```
