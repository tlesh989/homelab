#!/usr/bin/env python3
"""Homelab IP inventory: drift detection and free-IP lookup (read-only)."""
from dataclasses import dataclass
import pathlib

import yaml

BLOCKING = "BLOCKING"
ADVISORY = "ADVISORY"

_REPO = pathlib.Path(__file__).resolve().parent.parent
INVENTORY_PATH = _REPO / "group_vars" / "all" / "network_inventory.yml"
PIHOLE_DEFAULTS = _REPO / "roles" / "pi-hole" / "defaults" / "main.yml"
CADDY_DEFAULTS = _REPO / "roles" / "caddy" / "defaults" / "main.yml"


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


def inventory_ips(inventory):
    return {h["ip"] for h in inventory.get("hosts", [])}


def find_duplicate_ips(inventory):
    seen = {}
    for h in inventory.get("hosts", []):
        seen.setdefault(h["ip"], []).append(h["name"])
    return [
        Finding(BLOCKING, "duplicate-ip", f"{ip} claimed by: {', '.join(names)}")
        for ip, names in seen.items()
        if len(names) > 1
    ]


def cross_check_pihole(inventory, records):
    known = inventory_ips(inventory)
    return [
        Finding(BLOCKING, "pihole-unknown-ip",
                f"pi-hole maps {host} -> {ip}, but {ip} is not a documented host")
        for ip, host in records
        if ip not in known
    ]


def cross_check_caddy(inventory, services):
    known = inventory_ips(inventory)
    return [
        Finding(BLOCKING, "caddy-unknown-ip",
                f"caddy service {name} -> {ip}, but {ip} is not a documented host")
        for name, ip in services
        if ip not in known
    ]


def run_repo_checks(inventory, pihole_records, caddy_services):
    findings = []
    findings += find_duplicate_ips(inventory)
    findings += cross_check_pihole(inventory, pihole_records)
    findings += cross_check_caddy(inventory, caddy_services)
    return findings


def cmd_check(args):
    inventory = load_inventory(INVENTORY_PATH)
    findings = run_repo_checks(
        inventory,
        parse_pihole_records(PIHOLE_DEFAULTS),
        parse_caddy_services(CADDY_DEFAULTS),
    )
    print(format_report(findings))
    return 1 if has_blocking(findings) else 0
