#!/usr/bin/env python3
"""Homelab IP inventory: drift detection and free-IP lookup (read-only)."""
from dataclasses import dataclass

import yaml

BLOCKING = "BLOCKING"
ADVISORY = "ADVISORY"


@dataclass(frozen=True)
class Finding:
    severity: str
    category: str
    message: str


def has_blocking(findings):
    return any(f.severity == BLOCKING for f in findings)


def format_report(findings):
    if not findings:
        return "OK — no drift detected."
    lines = []
    for severity in (BLOCKING, ADVISORY):
        group = [f for f in findings if f.severity == severity]
        if group:
            lines.append(f"{severity} ({len(group)}):")
            for f in group:
                lines.append(f"  [{f.category}] {f.message}")
    return "\n".join(lines)


def load_inventory(path):
    with open(path) as fh:
        return yaml.safe_load(fh)


def parse_pihole_records(path):
    with open(path) as fh:
        data = yaml.safe_load(fh) or {}
    records = []
    for entry in data.get("pihole_local_hosts", []):
        parts = entry.split()
        if len(parts) < 2:
            continue
        ip, host = parts[0], parts[1]
        if "{{" in host:
            continue
        records.append((ip, host))
    return records


def parse_caddy_services(path):
    with open(path) as fh:
        data = yaml.safe_load(fh) or {}
    services = []
    for svc in data.get("caddy_services", []):
        ip = svc["upstream"].split(":")[0]
        services.append((svc["name"], ip))
    return services
