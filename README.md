# NetBar

NetBar is a small macOS Menu Bar app for seeing what your Mac currently knows about devices on your local network.

It sits quietly in the Menu Bar, performs a local-network lookup, reads the macOS ARP table, and shows nearby devices with IP address, optional MAC address, friendly names, guessed device type, and a simple network map.

Designed by Simon Stevens.

## What It Shows

- Devices recently visible in your Mac's ARP table.
- Active local subnet lookup on private LAN ranges, so nearby devices are easier to discover.
- IP address and network interface, such as `en0`.
- Optional MAC address display.
- First seen and last refreshed times.
- Whether an ARP entry is permanent.
- Friendly names you can save for devices.
- Guessed device categories, such as router, mobile, games console, computer, TV, printer, or smart-home kit.
- A visual Network Map with the router, this Mac, and discovered devices.
- Persistent network-baseline labels show whether a device is new to this network, normally seen, or likely just restarted.
- Restart-marked devices are highlighted after a known device disappears briefly and comes back, making it easier to rename the thing you just power-cycled.
- A per-device Ping IP action sends 6 pings and reports the average, or marks it as a bad ping if no reply arrives within 6 seconds.
- A Device Location Layer that takes background snapshots, stores them in local SQLite, and shows a radar-style confidence view for likely presence, mobility, novelty, and possible left-behind devices.
- The Device Radar includes the router anchor, a Network Map-matched key, and a selected-device details panel with IP and optional MAC address.
- Device Radar details include a pencil rename action that saves the same friendly name used by the Menu Bar list and Network Map.
- Device Radar details include a Zone calibration button. Confirmed zones such as Kitchen, Bedroom, Office, Living Room, Hallway, or Desk move that device on the radar and become part of its local identity profile.
- Device Radar filters this Mac and broadcast addresses, and deduplicates repeated Bluetooth records before drawing radar dots.
- Named devices build local identity profiles from recent IPs, MACs, hostnames, and radar zones. IP-only matches are treated as tentative, and MAC addresses can be locked when you want strict identity matching.

## Important Limits

NetBar is deliberately lightweight. It performs a short local-only lookup on your private LAN, then reads information your Mac has learned in the ARP table.

That means:

- Devices may only appear if they respond on the local network or are visible in your Mac's ARP table.
- DHCP/static status can only be known reliably for this Mac's own active interface.
- Other devices are shown as `DHCP/static unknown` unless their ARP entry itself is permanent.
- Device type guesses are hints, not facts. MAC address privacy features can make phones and laptops look anonymous.
- The Device Location Layer does not claim GPS or exact indoor positioning. It uses repeated local observations and confidence bands such as near Mac, home network present, Bluetooth nearby, away, or unknown.
- Room movement on the radar is a calibrated confidence hint. From one Mac alone, NetBar cannot prove that a device moved next to another appliance; use the Zone button when you confirm where a device is.
- Ping is only used for presence/liveness. NetBar does not use ping timing as a distance measurement.

## Download and Install

For a local build, run:

```sh
./scripts/build.sh
./scripts/package_dmg.sh
```

Then open:

```text
dist/NetBar.dmg
```

Drag `NetBar.app` into Applications and launch it. The app appears as a small network symbol in the macOS Menu Bar.

The default build is ad-hoc signed. On another Mac, macOS may ask you to approve it in Privacy & Security before opening.

## Build From Source

Requirements:

- macOS 11 or newer.
- Xcode Command Line Tools.
- The Xcode licence accepted.

If Swift prints a licence warning, run this once in Terminal:

```sh
sudo xcodebuild -license
```

Build and run:

```sh
./scripts/build.sh
open build/NetBar.app
```

Create a shareable DMG:

```sh
./scripts/package_dmg.sh
```

## Signing

By default, NetBar uses ad-hoc signing:

```sh
./scripts/build.sh
```

If you have an Apple Developer ID Application certificate, pass it like this:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh
./scripts/package_dmg.sh
```

For public distribution outside GitHub, you should also notarize the app with Apple.

## Launch at Login

NetBar can install a per-user LaunchAgent so it reopens when you log in:

```text
~/Library/LaunchAgents/local.netbar.status.login.plist
```

You can turn this on or off from NetBar's settings.

The setting is saved, so turning Launch at Login off stays off after the app restarts.

## Privacy

NetBar runs locally on your Mac. It does not upload your network data.

It stores friendly names and the MAC visibility preference here:

```text
~/Library/Application Support/NetBar/state.json
```

The Device Location Layer stores local snapshots and confidence scores here:

```text
~/Library/Application Support/NetBar/device-location-layer.sqlite
```

See [docs/PRIVACY.md](docs/PRIVACY.md) for more detail.

## Documentation

- [Install Guide](docs/INSTALL.md)
- [Distribution and Signing](docs/DISTRIBUTION.md)
- [GitHub Publishing](docs/GITHUB_PUBLISH.md)
- [Privacy Notes](docs/PRIVACY.md)
- [Contributing](CONTRIBUTING.md)

## Raw Scan Preview

To see the raw device data without building the app:

```sh
./scripts/scan_once.py
```

## Licence

NetBar is released under the MIT Licence. See [LICENSE](LICENSE).
