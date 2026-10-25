#!/usr/bin/env /usr/bin/python3
import subprocess
import re
import os
import glob
from platform import release, system, uname

def run_command(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.splitlines()

def parse_networkctl():
    networkctl = run_command("networkctl list")
    interfaces = {}
    for line in networkctl[1:]:  # Skip header
        parts = re.split(r'\s+', line.strip())
        if len(parts) >= 5:
            iface, setup = parts[1], parts[-1]
            interfaces[iface] = {"setup": setup, "config": None}
            for f in glob.glob("/etc/systemd/network/*.network"):
                with open(f, "r") as file:
                    if f"Name={iface}" in file.read() or "Name=*" in file.read():
                        interfaces[iface]["config"] = f
    return interfaces

def parse_nmcli():
    nmcli = run_command("nmcli device")
    interfaces = {}
    for line in nmcli[1:]:  # Skip header
        parts = re.split(r'\s+', line.strip())
        if len(parts) >= 4:
            iface, state, conn = parts[0], parts[2], parts[3]
            interfaces[iface] = {"state": state, "config": f"Connection: {conn}" if conn != "--" else None}
    return interfaces

def check_ifupdown():
    interfaces = {}
    if os.path.exists("/etc/network/interfaces"):
        with open("/etc/network/interfaces", "r") as f:
            for line in f:
                if line.strip().startswith(("iface ", "allow-hotplug ")):
                    parts = line.split()
                    if len(parts) > 1:
                        iface = parts[1] if parts[0] == "allow-hotplug" else parts[2]
                        interfaces[iface] = {"manager": "ifupdown", "config": "/etc/network/interfaces"}
    for file in glob.glob("/etc/network/interfaces.d/*"):
        with open(file, "r") as f:
            for line in f:
                if line.strip().startswith(("iface ", "allow-hotplug ")):
                    parts = line.split()
                    if len(parts) > 1:
                        iface = parts[1] if parts[0] == "allow-hotplug" else parts[2]
                        interfaces[iface] = {"manager": "ifupdown", "config": file}
    return interfaces

def print_system_info():
    os_info = "Raspberry Pi OS" if os.path.exists("/etc/rpi-issue") else "Unknown OS"
    with open("/etc/os-release", "r") as f:
        for line in f:
            if line.startswith("PRETTY_NAME="):
                os_info = line.split("=")[1].strip().strip('"')
                break
    kernel = release()
    print(f"System Information:")
    print(f"{'OS':<20}: {os_info}")
    print(f"{'Kernel':<20}: {kernel}")
    print()

def print_table(data):
    headers = ["Interface", "Manager", "Configuration Source"]
    max_len = [len(h) for h in headers]
    rows = []
    for iface, info in data.items():
        manager = info.get("manager", "Unmanaged or Unknown")
        config = info.get("config", "None")
        rows.append([iface, manager, config])
        max_len = [max(max_len[i], len(str(col))) for i, col in enumerate([iface, manager, config])]
    
    print("+" + "+".join("-" * (l + 2) for l in max_len) + "+")
    print("|" + "|".join(f" {h:<{max_len[i]}} " for i, h in enumerate(headers)) + "|")
    print("+" + "+".join("-" * (l + 2) for l in max_len) + "+")
    
    for row in sorted(rows, key=lambda x: x[0]):
        print("|" + "|".join(f" {col:<{max_len[i]}} " for i, col in enumerate(row)) + "|")
    print("+" + "+".join("-" * (l + 2) for l in max_len) + "+")

def main():
    print_system_info()
    print("Interfaces and Managers:")
    
    networkctl_ifaces = parse_networkctl()
    nmcli_ifaces = parse_nmcli()
    ifupdown_ifaces = check_ifupdown()
    
    all_ifaces = set(networkctl_ifaces.keys()) | set(nmcli_ifaces.keys()) | set(ifupdown_ifaces.keys())
    result = {}
    
    for iface in all_ifaces:
        if iface in ifupdown_ifaces:
            result[iface] = {"manager": "ifupdown", "config": ifupdown_ifaces[iface]["config"]}
        elif networkctl_ifaces.get(iface, {}).get("setup", "") in ["configured", "configuring"]:
            result[iface] = {"manager": "systemd-networkd", "config": networkctl_ifaces[iface]["config"]}
        elif nmcli_ifaces.get(iface, {}).get("state", "") in ["connected", "connecting"]:
            result[iface] = {"manager": "NetworkManager", "config": nmcli_ifaces[iface]["config"]}
        else:
            result[iface] = {"manager": "Unmanaged or Unknown", "config": "None"}
    
    print_table(result)

if __name__ == "__main__":
    main()
