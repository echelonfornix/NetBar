# NetBar

NetBar is a small macOS Menu Bar app for seeing what your Mac currently knows about devices on your local network.

It sits quietly in the Menu Bar, refreshes from the macOS ARP table, and shows nearby devices with IP address, optional MAC address, friendly names, guessed device type, and a simple network map.

Designed by Simon Stevens.

## What It Shows

- Devices recently visible in your Mac's ARP table.
- IP address and network interface, such as `en0`.
- Optional MAC address display.
- First seen and last refreshed times.
- Whether an ARP entry is permanent.
- Friendly names you can save for devices.
- Guessed device categories, such as router, mobile, games console, computer, TV, printer, or smart-home kit.
- A visual Network Map with the router, this Mac, and discovered devices.
- New devices are highlighted in both the Menu Bar list and Network Map for a few minutes after they appear.

## Important Limits

NetBar is deliberately lightweight. It reads information your Mac already has rather than aggressively scanning the network.

That means:

- Devices may only appear after your Mac has talked to them or recently discovered them.
- DHCP/static status can only be known reliably for this Mac's own active interface.
- Other devices are shown as `DHCP/static unknown` unless their ARP entry itself is permanent.
- Device type guesses are hints, not facts. MAC address privacy features can make phones and laptops look anonymous.

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

## Privacy

NetBar runs locally on your Mac. It does not upload your network data.

It stores friendly names and the MAC visibility preference here:

```text
~/Library/Application Support/NetBar/state.json
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
