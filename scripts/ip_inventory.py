#!/usr/bin/env python3
"""Homelab IP inventory: drift detection and free-IP lookup (read-only)."""
import ipaddress
import json
import pathlib
import subprocess
import sys
from dataclasses import dataclass

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
        data = yaml.safe_load(fh) or {}
    return data.get("network_inventory", data)


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
        upstream = svc.get("upstream", "")
        name = svc.get("name")
        if not upstream or not name or "{{" in upstream:
            continue
        ip = upstream.split(":")[0]
        services.append((name, ip))
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


def ips_in_range(lo, hi):
    start = int(ipaddress.IPv4Address(lo))
    end = int(ipaddress.IPv4Address(hi))
    return [str(ipaddress.IPv4Address(i)) for i in range(start, end + 1)]


def next_free_ip(lo, hi, used):
    used = set(used)
    for ip in ips_in_range(lo, hi):
        if ip not in used:
            return ip
    return None


def is_ip_free(ip, used):
    return ip not in set(used)


class UnifiError(Exception):
    pass


def _run_unifly(unifly_args):
    try:
        result = subprocess.run(
            ["unifly", *unifly_args],
            capture_output=True, text=True, timeout=30,
        )
    except FileNotFoundError:
        raise UnifiError("unifly not installed") from None
    except subprocess.TimeoutExpired:
        raise UnifiError("unifly timed out") from None
    if result.returncode != 0:
        raise UnifiError(result.stderr.strip() or "unifly returned non-zero")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        raise UnifiError("unifly did not return JSON") from None


def _records(payload):
    # unifly may return a bare list or wrap results in {"data": [...]}.
    if isinstance(payload, dict):
        if "data" in payload:
            return payload["data"]
        raise UnifiError(f"unexpected JSON shape: keys={sorted(payload.keys())}")
    return payload or []


def _normalize(item):
    return {
        "mac": (item.get("mac") or "").lower() or None,
        "ip": item.get("ip") or item.get("fixed_ip") or item.get("address"),
        "name": item.get("name") or item.get("hostname") or item.get("display_name"),
    }


def fetch_unifi_clients():
    # Confirmed: `unifly clients list -o json` (subcommand: clients, not client; flag: -o json, not --json)
    return [_normalize(c) for c in _records(_run_unifly(["clients", "list", "-o", "json"]))]


def fetch_unifi_reservations():
    # Confirmed: `unifly clients reservations -o json` (reservations is under `clients`, not `dhcp`)
    return [_normalize(r) for r in _records(_run_unifly(["clients", "reservations", "-o", "json"]))]


def gather_unifi_used():
    used = set()
    try:
        used |= {c["ip"] for c in fetch_unifi_clients() if c["ip"]}
        used |= {r["ip"] for r in fetch_unifi_reservations() if r["ip"]}
    except UnifiError as exc:
        print(f"WARNING: UniFi unavailable ({exc}); using inventory only.", file=sys.stderr)
    return used


def check_reservations(inventory, reservations):
    findings = []
    res_by_mac = {r["mac"].lower(): r["ip"] for r in reservations if r.get("mac")}
    for h in inventory.get("hosts", []):
        if h.get("assignment") != "reservation":
            continue
        mac = (h.get("mac") or "").lower()
        if not mac:
            findings.append(Finding(BLOCKING, "missing-mac",
                f"{h['name']} is assignment=reservation but has no MAC"))
            continue
        if mac not in res_by_mac:
            findings.append(Finding(BLOCKING, "missing-reservation",
                f"{h['name']} ({mac}) has no UniFi reservation"))
        elif res_by_mac[mac] != h["ip"]:
            findings.append(Finding(BLOCKING, "reservation-mismatch",
                f"{h['name']}: UniFi reserves {res_by_mac[mac]}, inventory says {h['ip']}"))
    return findings


def check_static_range_dynamic(inventory, clients, reservations):
    lo, hi = inventory["networks"]["main"]["static"]
    static_ips = set(ips_in_range(lo, hi))
    reserved = {r["ip"] for r in reservations if r.get("ip")}
    static_hosts = {h["ip"] for h in inventory.get("hosts", [])
                    if h.get("assignment") == "static"}
    findings = []
    for c in clients:
        ip = c.get("ip")
        if ip in static_ips and ip not in reserved and ip not in static_hosts:
            findings.append(Finding(BLOCKING, "dynamic-in-static",
                f"{c.get('name') or c.get('mac') or '<unknown>'} has dynamic lease {ip} inside static range {lo}-{hi}"))
    return findings


def find_undocumented_clients(inventory, clients):
    known = inventory_ips(inventory)
    return [
        Finding(ADVISORY, "undocumented-client",
                f"UniFi client {c.get('name') or c.get('mac') or '<unknown>'} ({c['ip']}) not in inventory")
        for c in clients
        if c.get("ip") and c["ip"] not in known
    ]


def cmd_reconcile(args):
    inventory = load_inventory(INVENTORY_PATH)
    findings = run_repo_checks(
        inventory,
        parse_pihole_records(PIHOLE_DEFAULTS),
        parse_caddy_services(CADDY_DEFAULTS),
    )
    try:
        clients = fetch_unifi_clients()
        reservations = fetch_unifi_reservations()
    except UnifiError as exc:
        print(f"WARNING: UniFi unavailable ({exc}); ran repo checks only.", file=sys.stderr)
        print(format_report(findings))
        return 1 if has_blocking(findings) else 0
    findings += check_reservations(inventory, reservations)
    findings += check_static_range_dynamic(inventory, clients, reservations)
    findings += find_undocumented_clients(inventory, clients)
    print(format_report(findings))
    return 1 if has_blocking(findings) else 0


def cmd_next(args):
    inventory = load_inventory(INVENTORY_PATH)
    lo, hi = inventory["networks"]["main"]["static"]
    used = inventory_ips(inventory)
    used |= gather_unifi_used()  # returns set(), warns on UnifiError
    if args.ip:
        print(f"{args.ip}: {'FREE' if is_ip_free(args.ip, used) else 'IN USE'}")
        return 0
    nxt = next_free_ip(lo, hi, used)
    print(nxt or "No free IP in static range")
    return 0


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(description="Homelab IP inventory tooling")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check", help="repo-internal drift check (no network)")
    sub.add_parser("reconcile", help="repo check + live UniFi reconcile")
    next_p = sub.add_parser("next", help="next free static IP, or check one")
    next_p.add_argument("ip", nargs="?", default=None, help="optional IP to test")

    args = parser.parse_args(argv)
    return {"check": cmd_check, "reconcile": cmd_reconcile, "next": cmd_next}[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
