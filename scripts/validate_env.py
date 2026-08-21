#!/usr/bin/env python3
from __future__ import annotations

import ipaddress
import sys

from envlib import load_env

NETWORKS = {
    "UNTRUSTED_SUBNET": ["ROUTER_UNTRUSTED_IP", "BANK_VPN_IP"],
    "DMZ_SUBNET": ["ROUTER_DMZ_IP", "BANK_PROXY_IP", "BANK_DBO_IP", "BANK_MFA_DBO_IP"],
    "SERVER_SUBNET": ["ROUTER_SERVER_IP", "BANK_ABS_IP", "BANK_ACC_SYS_IP", "BANK_MFA_ABS_IP"],
    "DATABASE_SUBNET": ["ROUTER_DATABASE_IP", "BANK_ABS_DB_IP"],
    "MANAGEMENT_SUBNET": ["ROUTER_MANAGEMENT_IP", "BANK_PAM_IP", "BANK_ADM_IP", "BANK_BACKUP_IP", "BANK_LDAP_IP"],
    "VLAN10_OPER_SUBNET": ["ROUTER_VLAN10_OPER_IP", "BANK_ARM_OPER_IP"],
    "VLAN20_CASH_SUBNET": ["ROUTER_VLAN20_CASH_IP", "BANK_ARM_CASH_IP"],
    "VLAN30_ACC_SUBNET": ["ROUTER_VLAN30_ACC_IP", "BANK_ARM_ACC_IP"],
    "VLAN40_IT_SUBNET": ["ROUTER_VLAN40_IT_IP", "BANK_ARM_IT_IP"],
}

PORTS = [
    "ARM_OPER_HOST_SSH_PORT", "ARM_CASH_HOST_SSH_PORT", "ARM_ACC_HOST_SSH_PORT", "ARM_IT_HOST_SSH_PORT",
    "ARM_OPER_HOST_RDP_PORT", "ARM_CASH_HOST_RDP_PORT", "ARM_ACC_HOST_RDP_PORT", "ARM_IT_HOST_RDP_PORT",
    "DBO_HOST_HTTP_PORT", "DBO_HOST_HTTPS_PORT", "VPN_HOST_PORT",
]

REQUIRED = {
    "COMPOSE_PROJECT_NAME", "LAB_ADMIN_USER", "LAB_ADMIN_PASSWORD", "LDAP_BASE_DN", "LDAP_ADMIN_DN",
    "LDAP_ADMIN_PASSWORD", "OPER_USER", "OPER_PASSWORD", "CASH_USER", "CASH_PASSWORD", "ACC_USER",
    "ACC_PASSWORD", "IT_USER", "IT_PASSWORD", "ABS_DB_NAME", "ABS_DB_USER", "ABS_DB_PASSWORD",
    "ACC_DB_NAME", "ACC_DB_USER", "ACC_DB_PASSWORD", "ABS_SOURCE_COMMIT", "DOLIBARR_SOURCE_COMMIT",
    "MFA_AUTHELIA_VERSION", "MFA_AUTHELIA_PORT", "MFA_DBO_APP_DOMAIN", "MFA_DBO_AUTH_DOMAIN",
    "MFA_ABS_APP_DOMAIN", "MFA_ABS_AUTH_DOMAIN", "SVC_DBO_USER", "SVC_DBO_PASSWORD",
    "SVC_ABS_USER", "SVC_ABS_PASSWORD",
}


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_env.py <env-file>", file=sys.stderr)
        return 2
    try:
        env = load_env(sys.argv[1])
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 2

    errors: list[str] = []
    for name in sorted(REQUIRED | set(NETWORKS) | set(PORTS)):
        if not env.get(name):
            fail(f"{name} is required", errors)

    parsed: dict[str, ipaddress.IPv4Network] = {}
    for name in NETWORKS:
        try:
            parsed[name] = ipaddress.ip_network(env.get(name, ""), strict=True)
        except ValueError as error:
            fail(f"{name}: {error}", errors)
    try:
        parsed["VPN_POOL"] = ipaddress.ip_network(env.get("VPN_POOL", ""), strict=True)
    except ValueError as error:
        fail(f"VPN_POOL: {error}", errors)

    names = list(parsed)
    for index, left_name in enumerate(names):
        for right_name in names[index + 1:]:
            if parsed[left_name].overlaps(parsed[right_name]):
                fail(f"{left_name} overlaps {right_name}", errors)

    seen: dict[ipaddress.IPv4Address, str] = {}
    for subnet_name, address_names in NETWORKS.items():
        subnet = parsed.get(subnet_name)
        if subnet is None:
            continue
        for address_name in address_names:
            try:
                address = ipaddress.ip_address(env.get(address_name, ""))
            except ValueError as error:
                fail(f"{address_name}: {error}", errors)
                continue
            if address not in subnet or address in {subnet.network_address, subnet.broadcast_address}:
                fail(f"{address_name}={address} is not a usable address in {subnet_name}={subnet}", errors)
            if address in seen:
                fail(f"{address_name} duplicates {seen[address]} ({address})", errors)
            seen[address] = address_name

    used_ports: dict[tuple[str, int], str] = {}
    for name in PORTS:
        try:
            port = int(env.get(name, ""))
            if not 1 <= port <= 65535:
                raise ValueError("outside 1..65535")
        except ValueError as error:
            fail(f"{name}: invalid port ({error})", errors)
            continue
        protocol = "udp" if name == "VPN_HOST_PORT" else "tcp"
        key = (protocol, port)
        if key in used_ports:
            fail(f"{name} duplicates {used_ports[key]} on {protocol}/{port}", errors)
        used_ports[key] = name

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Environment schema, addresses and ports are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
