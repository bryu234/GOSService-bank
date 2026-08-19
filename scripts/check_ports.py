#!/usr/bin/env python3
from __future__ import annotations

import json
import errno
import socket
import subprocess
import sys

from envlib import load_env

PORTS = [
    ("ARM_OPER_HOST_SSH_PORT", "tcp"), ("ARM_CASH_HOST_SSH_PORT", "tcp"),
    ("ARM_ACC_HOST_SSH_PORT", "tcp"), ("ARM_IT_HOST_SSH_PORT", "tcp"),
    ("ARM_OPER_HOST_RDP_PORT", "tcp"), ("ARM_CASH_HOST_RDP_PORT", "tcp"),
    ("ARM_ACC_HOST_RDP_PORT", "tcp"), ("ARM_IT_HOST_RDP_PORT", "tcp"),
    ("DBO_HOST_HTTP_PORT", "tcp"), ("DBO_HOST_HTTPS_PORT", "tcp"),
    ("VPN_HOST_PORT", "udp"),
]


def project_bindings(project: str) -> set[tuple[str, int]]:
    try:
        output = subprocess.check_output(
            ["docker", "ps", "--filter", f"label=com.docker.compose.project={project}", "--format", "{{json .Ports}}"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return set()
    result: set[tuple[str, int]] = set()
    for line in output.splitlines():
        try:
            rendered = json.loads(line)
        except json.JSONDecodeError:
            rendered = line
        for item in str(rendered).split(","):
            if "->" not in item or ":" not in item:
                continue
            left = item.split("->", 1)[0]
            protocol = "udp" if "/udp" in item else "tcp"
            try:
                result.add((protocol, int(left.rsplit(":", 1)[1])))
            except ValueError:
                pass
    return result


def lsof_reports_listener(port: int, protocol: str) -> bool:
    selector = f"-iUDP:{port}" if protocol == "udp" else f"-iTCP:{port}"
    command = ["lsof", "-nP", selector]
    if protocol == "tcp":
        command.append("-sTCP:LISTEN")
    try:
        return subprocess.run(
            command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        ).returncode == 0
    except FileNotFoundError:
        return True


def available(port: int, protocol: str) -> bool:
    sock_type = socket.SOCK_DGRAM if protocol == "udp" else socket.SOCK_STREAM
    with socket.socket(socket.AF_INET, sock_type) as sock:
        # A just-stopped Docker proxy may leave TCP TIME_WAIT entries. They do
        # not prevent a real listener that uses the normal SO_REUSEADDR flag.
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1 if protocol == "tcp" else 0)
        try:
            sock.bind(("0.0.0.0", port))
        except OSError as error:
            # Some managed development sandboxes forbid bind(2). In that case
            # retain the preflight by using the host's read-only socket table.
            if error.errno in (errno.EACCES, errno.EPERM):
                return not lsof_reports_listener(port, protocol)
            return False
    return True


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_ports.py <env-file>", file=sys.stderr)
        return 2
    env = load_env(sys.argv[1])
    owned = project_bindings(env.get("COMPOSE_PROJECT_NAME", "banklab"))
    failed = False
    for name, protocol in PORTS:
        port = int(env[name])
        if available(port, protocol):
            print(f"{name}: {protocol}/{port} is free")
        elif (protocol, port) in owned:
            print(f"{name}: {protocol}/{port} is already owned by this Compose project")
        else:
            print(f"ERROR: {name}: {protocol}/{port} is busy", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
