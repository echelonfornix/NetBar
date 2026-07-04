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

The setting is saved in NetBar's local state file. If you turn Launch at Login off, NetBar will not reinstall the LaunchAgent the next time it opens.

NetBar stores its LaunchAgent at:

```text
~/Library/LaunchAgents/local.netbar.status.login.plist
```

## New Device Highlighting

NetBar uses the first scan after launch as its baseline. Devices that appear after that are marked `NEW` in the Menu Bar list and highlighted on the Network Map for a few minutes.

## Local Network Lookup

On refresh, NetBar briefly probes the private/local IPv4 subnet for this Mac's active LAN address. That network access helps macOS populate the ARP table, which makes the device list and Network Map more complete.

## Device Location Layer

NetBar starts the Device Location Layer from launch and refreshes it with the normal background scan. Open `Device Radar...` from the Menu Bar menu to see the radar-style confidence view.

The radar shows the router as the fixed network anchor and uses the same device-type colours/icons as the Network Map. Select a radar dot to expand its IP, confidence zone, category, and MAC address when `Show MAC addresses` is enabled.

Use the pencil in the selected-device panel to save a friendly name. That name is shared with the Menu Bar list and Network Map.

The radar view filters this Mac and broadcast addresses, then deduplicates repeated Bluetooth records so the view stays focused on real device dots.

The layer stores snapshots locally in:

```text
~/Library/Application Support/NetBar/device-location-layer.sqlite
```

From a device submenu you can mark a device as static, mobile, or ignored for the location model. Use `Reset Learned Baseline...` if you want NetBar to forget the snapshot history and start learning again.

## Ping a Device

Open a device submenu and choose `Ping IP (6 avg)`. NetBar sends 6 pings and reports the average response time. If no reply arrives within 6 seconds, the result is shown as a bad ping.
