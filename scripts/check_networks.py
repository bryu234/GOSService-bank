#!/usr/bin/env python3
from __future__ import annotations

import ipaddress
import json
import platform
import re
import subprocess
import sys

from envlib import load_env

NETWORKS = {
    "UNTRUSTED_SUBNET": "bank_net_untrusted",
    "DMZ_SUBNET": "bank_net_dmz",
    "SERVER_SUBNET": "bank_net_server",
    "DATABASE_SUBNET": "bank_net_database",
    "MANAGEMENT_SUBNET": "bank_net_management",
    "VLAN10_OPER_SUBNET": "bank_net_vlan10_oper",
    "VLAN20_CASH_SUBNET": "bank_net_vlan20_cash",
    "VLAN30_ACC_SUBNET": "bank_net_vlan30_acc",
    "VLAN40_IT_SUBNET": "bank_net_vlan40_it",
}


def docker_networks() -> list[tuple[str, ipaddress._BaseNetwork]]:
    ids = subprocess.check_output(["docker", "network", "ls", "-q"], text=True).split()
    if not ids:
        return []
    data = json.loads(subprocess.check_output(["docker", "network", "inspect", *ids], text=True))
    result = []
    for network in data:
        for config in (network.get("IPAM") or {}).get("Config") or []:
            if config.get("Subnet"):
                result.append((network.get("Name", "<unknown>"), ipaddress.ip_network(config["Subnet"], strict=False)))
    return result


def host_routes() -> list[ipaddress._BaseNetwork]:
    if platform.system() == "Linux":
        command = ["ip", "-4", "route", "show"]
    else:
        command = ["netstat", "-rn", "-f", "inet"]
    output = subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL)
    result = []
    for token in re.findall(r"(?:\d{1,3}\.){1,3}\d{1,3}(?:/\d{1,2})?", output):
        if token.count(".") != 3:
            continue
        try:
            network = ipaddress.ip_network(token, strict=False)
        except ValueError:
            continue
        if network.prefixlen and not network.is_loopback and not network.is_link_local:
            result.append(network)
    return result


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_networks.py <env-file>", file=sys.stderr)
        return 2
    env = load_env(sys.argv[1])
    requested = {key: ipaddress.ip_network(env[key]) for key in NETWORKS}
    requested["VPN_POOL"] = ipaddress.ip_network(env["VPN_POOL"])
    try:
        existing = docker_networks()
    except (FileNotFoundError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"ERROR: cannot inspect Docker networks: {error}", file=sys.stderr)
        return 2
    routes = host_routes()
    failed = False
    for key, subnet in requested.items():
        managed_name = NETWORKS.get(key)
        managed_present = any(name == managed_name and subnet == other for name, other in existing)
        key_failed = False
        for name, other in existing:
            if subnet.version != other.version or not subnet.overlaps(other):
                continue
            if name == managed_name and subnet == other:
                continue
            print(f"ERROR: {key}={subnet} overlaps Docker network {name}={other}", file=sys.stderr)
            failed = True
            key_failed = True
        for route in routes:
            if subnet.version == route.version and subnet.overlaps(route):
                # Docker adds the running project's bridge subnet and gateway
                # to the host route table. They are expected when preflight is
                # repeated before an in-place `compose up`.
                if managed_present and route.subnet_of(subnet):
                    continue
                print(f"ERROR: {key}={subnet} overlaps host route {route}", file=sys.stderr)
                failed = True
                key_failed = True
        if not key_failed:
            print(f"{key}: {subnet} has no detected conflict")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
