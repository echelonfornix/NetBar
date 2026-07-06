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

## New, Normal, and Restarted Devices

NetBar keeps a local network-baseline record in its state file. Devices with only a few sightings are marked `NEW`; devices seen repeatedly become `Normally seen on this network`.

If a normally seen device disappears briefly and then comes back, NetBar marks it as `RESTART`. This is useful when you power-cycle a plug, console, speaker, TV, or other device: refresh NetBar, find the restart-marked item, then use `Rename...` while it is obvious what you just turned back on.

Use `Hunt Device...` when you deliberately want to identify something. Start the hunt, leave the device on for the first scan, turn the mystery device off for at least 15 seconds, wait for NetBar to mark a likely `OFF?` candidate, turn it back on, then rename the `RESTART` candidate. Hunt mode scans every 4 seconds for 5 minutes.

This works best for devices that answer local probes. Devices that block ping may still stay visible from stale ARP information, so NetBar treats the result as a useful hint rather than certainty.

When a device is marked `RESTART`, use `Confirm Restart...` to rename it, clear the mark without renaming, or keep the mark visible while you decide.

Use `Clear Name` to remove the saved friendly name and the learned identity links for that device. NetBar may still show a real hostname if macOS reports one from the network.

## Local Network Lookup

On refresh, NetBar briefly probes the private/local IPv4 subnet for this Mac's active LAN address. That network access helps macOS populate the ARP table, which makes the device list and Network Map more complete.

## Device Location Layer

NetBar starts the Device Location Layer from launch and refreshes it with the normal background scan. Open `Device Radar...` from the Menu Bar menu to see the radar-style confidence view.

The radar shows the router as the fixed network anchor and uses the same device-type colours/icons as the Network Map. Select a radar dot to expand its IP, confidence zone, category, and MAC address when `Show MAC addresses` is enabled.

Use the pencil in the selected-device panel to save a friendly name. That name is shared with the Menu Bar list and Network Map.

Use `Zone` in the selected-device panel when you confirm a device is in Kitchen, Bedroom, Office, Living Room, Hallway, or Desk. NetBar stores that as a local calibration hint, moves the device on the radar, and uses the confirmed zone as part of the friendly-name identity profile.

The radar view filters this Mac and broadcast addresses, then deduplicates repeated Bluetooth records so the view stays focused on real device dots.

Named devices build an identity profile over time. NetBar remembers recent IPs, MACs, hostnames, and radar zones for that friendly name. If only the IP matches, NetBar treats it as tentative because another device could receive the same address later. Use `Identity: Lock Current MAC` from a named device's menu when you want strict MAC matching for devices that do not rotate private addresses.

The layer stores snapshots locally in:

```text
~/Library/Application Support/NetBar/device-location-layer.sqlite
```

From a device submenu you can mark a device as static, mobile, or ignored for the location model. Use `Reset Learned Baseline...` if you want NetBar to forget the snapshot history and start learning again.

## Ping a Device

Open a device submenu and choose `Ping IP (6 avg)`. NetBar sends 6 pings and reports the average response time. If no reply arrives within 6 seconds, the result is shown as a bad ping.
