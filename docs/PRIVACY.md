# Privacy Notes

NetBar is local-first.

It reads:

- The macOS ARP table using `arp`.
- The active network interface using `route` and `ipconfig`.
- Local DHCP packet details for this Mac's own interface where available.
- Private/local IPv4 subnet addresses using short local ping probes, so macOS can populate ARP entries for nearby devices.
- Best-effort Wi-Fi status from macOS system information, where available.
- Best-effort Bluetooth device information from macOS system information, where available.

It stores:

- Friendly names you assign to devices.
- Whether MAC addresses should be visible in the menu.
- Whether Launch at Login should be enabled.
- Local network-baseline records, including first seen, last seen, seen count, missing count, and short restart-mark status for devices.
- Device Location Layer snapshots, observations, confidence scores, and learned baselines.
- Local identity profiles for friendly-named devices, including recent IPs, MACs, hostnames, observed zones, confirmed zone calibration hints, and optional locked MAC addresses.

Stored data location:

```text
~/Library/Application Support/NetBar/state.json
~/Library/Application Support/NetBar/device-location-layer.sqlite
```

NetBar does not upload network data, send analytics, or contact a remote service. Its lookup traffic stays on the local/private subnet.

## Device Location Layer

The Device Location Layer is local-only. It learns from repeated snapshots of devices your Mac can already observe through local network and system information.

It reports confidence states rather than exact locations. For example, it may say a device is probably `Home network present` or `Bluetooth nearby`, but it should not be read as GPS, room-level truth, or exact distance.

Ping replies are used only as a presence signal. Wi-Fi and Bluetooth signal strength can be noisy, so NetBar treats them as hints and combines them with repeated observations over time.

Confirmed room zones are user-supplied calibration hints. They stay local and are used to move the device on the radar, not to claim exact physical positioning.

## Device Type Guesses

Device guesses come from local clues such as:

- IP address patterns that often indicate a router.
- Hostnames already visible to macOS.
- MAC address privacy flags.
- Whether a MAC address appears vendor-assigned or locally administered.

These are only hints. Privacy features on modern phones, tablets, and laptops can deliberately hide the real vendor.
