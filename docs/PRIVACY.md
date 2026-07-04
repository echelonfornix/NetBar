# Privacy Notes

NetBar is local-first.

It reads:

- The macOS ARP table using `arp`.
- The active network interface using `route` and `ipconfig`.
- Local DHCP packet details for this Mac's own interface where available.
- Private/local IPv4 subnet addresses using short local ping probes, so macOS can populate ARP entries for nearby devices.

It stores:

- Friendly names you assign to devices.
- Whether MAC addresses should be visible in the menu.
- Whether Launch at Login should be enabled.

Stored data location:

```text
~/Library/Application Support/NetBar/state.json
```

NetBar does not upload network data, send analytics, or contact a remote service. Its lookup traffic stays on the local/private subnet.

## Device Type Guesses

Device guesses come from local clues such as:

- IP address patterns that often indicate a router.
- Hostnames already visible to macOS.
- MAC address privacy flags.
- Whether a MAC address appears vendor-assigned or locally administered.

These are only hints. Privacy features on modern phones, tablets, and laptops can deliberately hide the real vendor.
