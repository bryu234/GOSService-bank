#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


def load_env(path: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for number, raw in enumerate(Path(path).read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"{path}:{number}: expected KEY=VALUE")
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if value[:1] in {'\"', "'"} and value[-1:] == value[:1]:
            value = value[1:-1]
        values[key] = value
    return values
