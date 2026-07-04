#!/usr/bin/env python3
import json
import re
import subprocess
from datetime import datetime


ARP_PATTERN = re.compile(r"^(?P<host>.*?)\s*\((?P<ip>\d{1,3}(?:\.\d{1,3}){3})\)\s+at\s+(?P<mac>\S+)\s+on\s+(?P<interface>\S+)(?P<rest>.*)$")


def run(command):
    try:
        return subprocess.run(command, text=True, capture_output=True, check=False).stdout
    except OSError:
        return ""


def ignored_ip(ip):
    first = int(ip.split(".")[0])
    return 224 <= first <= 239 or ip == "255.255.255.255"


def default_interface():
    output = run(["/sbin/route", "-n", "get", "default"])
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("interface:"):
            return line.replace("interface:", "", 1).strip()
    counts = {}
    for line in run(["/usr/sbin/arp", "-a"]).splitlines():
        match = ARP_PATTERN.match(line)
        if match:
            interface = match.group("interface")
            counts[interface] = counts.get(interface, 0) + 1
    if counts:
        return sorted(counts.items(), key=lambda item: (-item[1], item[0]))[0][0]
    return None


def local_permanent_arp_address(interface):
    for line in run(["/usr/sbin/arp", "-a"]).splitlines():
        match = ARP_PATTERN.match(line)
        if not match or " permanent" not in match.group("rest"):
            continue
        if interface and match.group("interface") != interface:
            continue
        ip = match.group("ip")
        if not ignored_ip(ip):
            return ip
    return None


def local_info():
    interface = default_interface()
    ip = None
    assignment = "No active address found"

    if interface:
        ip = run(["/usr/sbin/ipconfig", "getifaddr", interface]).strip() or None
        ip = ip or local_permanent_arp_address(interface)
        packet = run(["/usr/sbin/ipconfig", "getpacket", interface])
        if any(token in packet for token in ("lease_time", "server_identifier", "yiaddr")):
            assignment = "DHCP"
        elif ip == local_permanent_arp_address(interface):
            assignment = "Local address; DHCP/static unknown"
        elif ip:
            assignment = "Static/manual or unknown"

    return {
        "interface": interface,
        "ip": ip,
        "assignment": assignment,
    }


def scan():
    devices = []
    now = datetime.now().isoformat(timespec="seconds")

    for line in run(["/usr/sbin/arp", "-a"]).splitlines():
        match = ARP_PATTERN.match(line)
        if not match:
            continue

        data = match.groupdict()
        if data["mac"] in {"(incomplete)", "<incomplete>"} or ignored_ip(data["ip"]):
            continue

        host = data["host"].strip()
        devices.append({
            "name": None if host in {"", "?"} else host,
            "ip": data["ip"],
            "mac": data["mac"].lower(),
            "interface": data["interface"],
            "address_status": "Static ARP entry" if " permanent" in data["rest"] else "DHCP/static unknown",
            "last_refreshed": now,
        })

    return sorted(devices, key=lambda item: tuple(int(part) for part in item["ip"].split(".")))


if __name__ == "__main__":
    print(json.dumps({
        "refreshed": datetime.now().isoformat(timespec="seconds"),
        "this_mac": local_info(),
        "devices": scan(),
    }, indent=2))
