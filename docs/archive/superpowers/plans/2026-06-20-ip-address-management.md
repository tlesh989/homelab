# IP Address Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a structured network inventory plus read-only Python tooling that detects IP/DNS drift across the repo, pi-hole, Caddy, and UniFi, and answers "is this IP free?" before assignment.

**Architecture:** A single inventory YAML in `group_vars/` is the source of truth for infrastructure. One Python script (`scripts/ip_inventory.py`) with pure check functions + a thin `unifly` adapter exposes three subcommands (`check`, `reconcile`, `next`) wired to `task` commands. No writes to any system; UniFi access is local-only and degrades gracefully.

**Tech Stack:** Python 3 (stdlib + PyYAML), pytest, `unifly` CLI (JSON output), go-task (Taskfile), Ansible group_vars.

## Global Constraints

- Read-only: no writes to UniFi, pi-hole, or Caddy. Copied verbatim from spec Non-Goals.
- Severity model: `BLOCKING` = duplicate inventory IP, pi-hole/Caddy IP absent from inventory, reservation missing/mismatch, missing MAC on a reservation host, dynamic lease inside a static range. `ADVISORY` = UniFi client absent from inventory, host offline, unknown MAC.
- A non-zero process exit iff any `BLOCKING` finding exists.
- Inventory lives at `group_vars/all/network_inventory.yml` so Phase 2 Ansible roles can consume it with no migration.
- Pure functions take/return plain dicts/lists/`Finding`s; all I/O (`unifly`, file reads) is isolated so checks are unit-testable without a network or live files.
- Follow repo conventions: `rtk` prefix on git/task commands at execution time; commit messages use `feat:`/`fix:`/`chore:` and end with the `Co-Authored-By` trailer.

---

## File Structure

- `scripts/ip_inventory.py` — the entire tool: `Finding` model, pure check functions, `unifly` adapter, argparse CLI. One file: the logic is cohesive and small enough to hold in context.
- `tests/test_ip_inventory.py` — unit tests for every pure function.
- `tests/conftest.py` — puts `scripts/` on `sys.path` so the module imports.
- `group_vars/all/connection.yml` — existing `group_vars/all.yml` content, moved verbatim.
- `group_vars/all/network_inventory.yml` — the new structured inventory.
- `Taskfile.yml` — add `ip:check`, `ip:reconcile`, `ip:next`.
- `.github/workflows/ci.yml` — add the `ip:check` gate.

---

### Task 1: Finding model + report formatter

**Files:**
- Create: `scripts/ip_inventory.py`
- Create: `tests/conftest.py`
- Create: `tests/test_ip_inventory.py`

**Interfaces:**
- Produces: `BLOCKING: str`, `ADVISORY: str` constants; `Finding(severity, category, message)` frozen dataclass; `has_blocking(findings: list[Finding]) -> bool`; `format_report(findings: list[Finding]) -> str`.

- [ ] **Step 1: Ensure test deps are present**

Run: `python -c "import yaml, pytest"`
If it raises `ModuleNotFoundError`, add `pyyaml` and `pytest` to `requirements-dev.txt` and run `pip install -r requirements-dev.txt` inside the repo `.venv`.
Expected: no output (both import).

- [ ] **Step 2: Create `tests/conftest.py`**

```python
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "scripts"))
```

- [ ] **Step 3: Write the failing test**

In `tests/test_ip_inventory.py`:

```python
from ip_inventory import ADVISORY, BLOCKING, Finding, format_report, has_blocking


def test_has_blocking_true_when_any_blocking():
    findings = [Finding(ADVISORY, "x", "a"), Finding(BLOCKING, "y", "b")]
    assert has_blocking(findings) is True


def test_has_blocking_false_when_only_advisory():
    assert has_blocking([Finding(ADVISORY, "x", "a")]) is False


def test_format_report_groups_blocking_first():
    findings = [
        Finding(ADVISORY, "undocumented-client", "phone (.55) not in inventory"),
        Finding(BLOCKING, "duplicate-ip", ".7 claimed by tika, bupu"),
    ]
    report = format_report(findings)
    assert report.index("BLOCKING") < report.index("ADVISORY")
    assert "duplicate-ip" in report
    assert "undocumented-client" in report


def test_format_report_ok_when_empty():
    assert "no drift" in format_report([]).lower()
```

- [ ] **Step 4: Run test to verify it fails**

Run: `pytest tests/test_ip_inventory.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'ip_inventory'`.

- [ ] **Step 5: Write minimal implementation**

In `scripts/ip_inventory.py`:

```python
#!/usr/bin/env python3
"""Homelab IP inventory: drift detection and free-IP lookup (read-only)."""
from dataclasses import dataclass

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
```

- [ ] **Step 6: Run test to verify it passes**

Run: `pytest tests/test_ip_inventory.py -v`
Expected: PASS (4 passed).

- [ ] **Step 7: Commit**

```bash
git add scripts/ip_inventory.py tests/conftest.py tests/test_ip_inventory.py requirements-dev.txt
git commit -m "feat(network): add Finding model and report formatter for IP tooling"
```

---

### Task 2: Inventory + pi-hole + Caddy loaders

**Files:**
- Modify: `scripts/ip_inventory.py`
- Test: `tests/test_ip_inventory.py`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: `load_inventory(path) -> dict`; `parse_pihole_records(path) -> list[tuple[str, str]]` (each `(ip, hostname)`); `parse_caddy_services(path) -> list[tuple[str, str]]` (each `(name, upstream_ip)`).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_ip_inventory.py`:

```python
import textwrap

from ip_inventory import load_inventory, parse_caddy_services, parse_pihole_records


def test_load_inventory_reads_yaml(tmp_path):
    p = tmp_path / "inv.yml"
    p.write_text(textwrap.dedent("""
        networks:
          main: {cidr: 192.168.233.0/24, static: ["192.168.233.1", "192.168.233.50"]}
        hosts:
          - {name: tika, ip: 192.168.233.7, mac: null, assignment: static, dns: [tika.tlesh.xyz]}
    """))
    inv = load_inventory(str(p))
    assert inv["hosts"][0]["name"] == "tika"
    assert inv["networks"]["main"]["static"] == ["192.168.233.1", "192.168.233.50"]


def test_parse_pihole_records_splits_and_skips_jinja(tmp_path):
    p = tmp_path / "pihole.yml"
    p.write_text(textwrap.dedent("""
        pihole_local_hosts:
          - "192.168.233.3 pi-hole.tlesh.xyz"
          - "192.168.233.125 homeassistant.tlesh.xyz"
          - "192.168.233.19 {{ lookup('env', 'MINECRAFT_SERVER') }}"
    """))
    records = parse_pihole_records(str(p))
    assert ("192.168.233.3", "pi-hole.tlesh.xyz") in records
    assert ("192.168.233.125", "homeassistant.tlesh.xyz") in records
    assert all("{{" not in host for _, host in records)
    assert len(records) == 2


def test_parse_caddy_services_extracts_ip(tmp_path):
    p = tmp_path / "caddy.yml"
    p.write_text(textwrap.dedent("""
        caddy_services:
          - {name: uptime-kuma, upstream: "192.168.233.16:3001"}
          - {name: n8n, upstream: "192.168.233.10:5678"}
    """))
    services = parse_caddy_services(str(p))
    assert ("uptime-kuma", "192.168.233.16") in services
    assert ("n8n", "192.168.233.10") in services
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_ip_inventory.py -k "load_inventory or pihole or caddy" -v`
Expected: FAIL — `ImportError: cannot import name 'load_inventory'`.

- [ ] **Step 3: Write minimal implementation**

Add to `scripts/ip_inventory.py` (and add `import yaml` near the top):

```python
import yaml


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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_ip_inventory.py -k "load_inventory or pihole or caddy" -v`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
git add scripts/ip_inventory.py tests/test_ip_inventory.py
git commit -m "feat(network): add inventory/pi-hole/caddy loaders for IP tooling"
```

---

### Task 3: Repo-internal checks + `check` subcommand

**Files:**
- Modify: `scripts/ip_inventory.py`
- Test: `tests/test_ip_inventory.py`

**Interfaces:**
- Consumes: `Finding`, `BLOCKING`, `ADVISORY`, `load_inventory`, `parse_pihole_records`, `parse_caddy_services`, `format_report`, `has_blocking`.
- Produces: `inventory_ips(inventory) -> set[str]`; `find_duplicate_ips(inventory) -> list[Finding]`; `cross_check_pihole(inventory, records) -> list[Finding]`; `cross_check_caddy(inventory, services) -> list[Finding]`; `run_repo_checks(inventory, pihole_records, caddy_services) -> list[Finding]`; module path constants `INVENTORY_PATH`, `PIHOLE_DEFAULTS`, `CADDY_DEFAULTS`; `cmd_check(args) -> int`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_ip_inventory.py`:

```python
from ip_inventory import (
    cross_check_caddy,
    cross_check_pihole,
    find_duplicate_ips,
    inventory_ips,
    run_repo_checks,
)

INV = {
    "networks": {"main": {"static": ["192.168.233.1", "192.168.233.50"]}},
    "hosts": [
        {"name": "tika", "ip": "192.168.233.7", "dns": ["tika.tlesh.xyz"]},
        {"name": "caddy", "ip": "192.168.233.17", "dns": ["caddy.tlesh.xyz"]},
        {"name": "homeassistant", "ip": "192.168.233.35", "dns": ["homeassistant.tlesh.xyz"]},
    ],
}


def test_inventory_ips():
    assert inventory_ips(INV) == {"192.168.233.7", "192.168.233.17", "192.168.233.35"}


def test_find_duplicate_ips_flags_collision():
    inv = {"hosts": [
        {"name": "a", "ip": "192.168.233.7"},
        {"name": "b", "ip": "192.168.233.7"},
    ]}
    findings = find_duplicate_ips(inv)
    assert len(findings) == 1
    assert findings[0].severity == BLOCKING
    assert findings[0].category == "duplicate-ip"


def test_cross_check_pihole_blocks_unknown_ip():
    # homeassistant actually points at .125 in pi-hole; inventory says .35
    records = [("192.168.233.125", "homeassistant.tlesh.xyz"),
               ("192.168.233.17", "caddy.tlesh.xyz")]
    findings = cross_check_pihole(INV, records)
    assert [f.message for f in findings if f.severity == BLOCKING]
    assert any("192.168.233.125" in f.message for f in findings)
    # .17 is a known host -> no finding for it
    assert not any("192.168.233.17" in f.message for f in findings)


def test_cross_check_caddy_blocks_unknown_ip():
    services = [("uptime-kuma", "192.168.233.16"), ("n8n", "192.168.233.7")]
    findings = cross_check_caddy(INV, services)
    assert any(f.severity == BLOCKING and "192.168.233.16" in f.message for f in findings)
    assert not any("192.168.233.7" in f.message for f in findings)


def test_run_repo_checks_aggregates():
    findings = run_repo_checks(
        INV,
        [("192.168.233.125", "homeassistant.tlesh.xyz")],
        [("uptime-kuma", "192.168.233.16")],
    )
    assert has_blocking(findings)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_ip_inventory.py -k "inventory_ips or duplicate or cross_check or repo_checks" -v`
Expected: FAIL — `ImportError: cannot import name 'inventory_ips'`.

- [ ] **Step 3: Write minimal implementation**

Add to `scripts/ip_inventory.py` (and `import pathlib` near the top):

```python
import pathlib

_REPO = pathlib.Path(__file__).resolve().parent.parent
INVENTORY_PATH = _REPO / "group_vars" / "all" / "network_inventory.yml"
PIHOLE_DEFAULTS = _REPO / "roles" / "pi-hole" / "defaults" / "main.yml"
CADDY_DEFAULTS = _REPO / "roles" / "caddy" / "defaults" / "main.yml"


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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_ip_inventory.py -k "inventory_ips or duplicate or cross_check or repo_checks" -v`
Expected: PASS (5 passed).

- [ ] **Step 5: Commit**

```bash
git add scripts/ip_inventory.py tests/test_ip_inventory.py
git commit -m "feat(network): add repo-internal IP/DNS drift checks and check command"
```

---

### Task 4: IP-range helpers + `next` subcommand

**Files:**
- Modify: `scripts/ip_inventory.py`
- Test: `tests/test_ip_inventory.py`

**Interfaces:**
- Consumes: `inventory_ips`, `load_inventory`.
- Produces: `ips_in_range(lo, hi) -> list[str]`; `next_free_ip(lo, hi, used) -> str | None`; `is_ip_free(ip, used) -> bool`; `cmd_next(args) -> int` (uses `args.ip` which is `None` or a string). Note: `cmd_next` calls `gather_unifi_used(...)` defined in Task 5; until then it falls back to inventory-only — Step 3 below ships the inventory-only form and Task 5 extends it.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_ip_inventory.py`:

```python
from ip_inventory import ips_in_range, is_ip_free, next_free_ip


def test_ips_in_range_inclusive():
    rng = ips_in_range("192.168.233.1", "192.168.233.3")
    assert rng == ["192.168.233.1", "192.168.233.2", "192.168.233.3"]


def test_next_free_ip_skips_used():
    used = {"192.168.233.1", "192.168.233.2"}
    assert next_free_ip("192.168.233.1", "192.168.233.5", used) == "192.168.233.3"


def test_next_free_ip_none_when_full():
    used = set(ips_in_range("192.168.233.1", "192.168.233.2"))
    assert next_free_ip("192.168.233.1", "192.168.233.2", used) is None


def test_is_ip_free():
    assert is_ip_free("192.168.233.9", {"192.168.233.7"}) is True
    assert is_ip_free("192.168.233.7", {"192.168.233.7"}) is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_ip_inventory.py -k "in_range or next_free or is_ip_free" -v`
Expected: FAIL — `ImportError: cannot import name 'ips_in_range'`.

- [ ] **Step 3: Write minimal implementation**

Add to `scripts/ip_inventory.py` (and `import ipaddress` near the top):

```python
import ipaddress


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


def cmd_next(args):
    inventory = load_inventory(INVENTORY_PATH)
    lo, hi = inventory["networks"]["main"]["static"]
    used = inventory_ips(inventory)
    used |= gather_unifi_used()  # defined in Task 5; returns set(), warns on failure
    if args.ip:
        print(f"{args.ip}: {'FREE' if is_ip_free(args.ip, used) else 'IN USE'}")
        return 0
    nxt = next_free_ip(lo, hi, used)
    print(nxt or "No free IP in static range")
    return 0
```

Note: `gather_unifi_used` is added in Task 5. If executing Task 4 in isolation, temporarily define `def gather_unifi_used(): return set()` at module scope; Task 5 replaces it.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_ip_inventory.py -k "in_range or next_free or is_ip_free" -v`
Expected: PASS (4 passed).

- [ ] **Step 5: Commit**

```bash
git add scripts/ip_inventory.py tests/test_ip_inventory.py
git commit -m "feat(network): add free-IP lookup and next command"
```

---

### Task 5: UniFi adapter + reconcile checks + `reconcile` subcommand + CLI entrypoint

**Files:**
- Modify: `scripts/ip_inventory.py`
- Test: `tests/test_ip_inventory.py`

**Interfaces:**
- Consumes: everything above.
- Produces: `UnifiError(Exception)`; `fetch_unifi_clients() -> list[dict]` and `fetch_unifi_reservations() -> list[dict]` (each dict has `mac`, `ip`, `name`); `gather_unifi_used() -> set[str]`; pure checks `check_reservations(inventory, reservations) -> list[Finding]`, `check_static_range_dynamic(inventory, clients, reservations) -> list[Finding]`, `find_undocumented_clients(inventory, clients) -> list[Finding]`; `cmd_reconcile(args) -> int`; `main(argv=None) -> int`.

- [ ] **Step 1: Write the failing test (pure reconcile checks only)**

Append to `tests/test_ip_inventory.py`:

```python
from ip_inventory import (
    check_reservations,
    check_static_range_dynamic,
    find_undocumented_clients,
)

RINV = {
    "networks": {"main": {"static": ["192.168.233.1", "192.168.233.50"]}},
    "hosts": [
        {"name": "kaz", "ip": "192.168.233.10", "mac": "bc:24:11:10:00:01",
         "assignment": "reservation"},
        {"name": "tika", "ip": "192.168.233.7", "mac": None, "assignment": "static"},
        {"name": "macbook", "ip": "192.168.233.25", "mac": None,
         "assignment": "dynamic-noted"},
    ],
}


def test_check_reservations_flags_missing():
    findings = check_reservations(RINV, reservations=[])
    assert any(f.category == "missing-reservation" and f.severity == BLOCKING
               for f in findings)


def test_check_reservations_flags_ip_mismatch():
    res = [{"mac": "bc:24:11:10:00:01", "ip": "192.168.233.99", "name": "kaz"}]
    findings = check_reservations(RINV, res)
    assert any(f.category == "reservation-mismatch" for f in findings)


def test_check_reservations_ok_on_match():
    res = [{"mac": "BC:24:11:10:00:01", "ip": "192.168.233.10", "name": "kaz"}]
    assert check_reservations(RINV, res) == []


def test_check_static_range_dynamic_flags_macbook():
    clients = [{"mac": "aa:bb:cc:dd:ee:ff", "ip": "192.168.233.25", "name": "macbook"}]
    findings = check_static_range_dynamic(RINV, clients, reservations=[])
    assert any(f.category == "dynamic-in-static" and f.severity == BLOCKING
               for f in findings)


def test_check_static_range_dynamic_ignores_reserved():
    clients = [{"mac": "bc:24:11:10:00:01", "ip": "192.168.233.10", "name": "kaz"}]
    res = [{"mac": "bc:24:11:10:00:01", "ip": "192.168.233.10", "name": "kaz"}]
    assert check_static_range_dynamic(RINV, clients, res) == []


def test_find_undocumented_clients_is_advisory():
    clients = [{"mac": "11:22:33:44:55:66", "ip": "192.168.233.88", "name": "phone"}]
    findings = find_undocumented_clients(RINV, clients)
    assert findings and all(f.severity == ADVISORY for f in findings)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_ip_inventory.py -k "reservations or static_range or undocumented" -v`
Expected: FAIL — `ImportError: cannot import name 'check_reservations'`.

- [ ] **Step 3: Write minimal implementation**

If you added a temporary `gather_unifi_used` stub in Task 4, delete it first. Add to `scripts/ip_inventory.py` (and `import json`, `import subprocess`, `import sys` near the top):

```python
import json
import subprocess
import sys


class UnifiError(Exception):
    pass


def _run_unifly(unifly_args):
    try:
        result = subprocess.run(
            ["unifly", *unifly_args],
            capture_output=True, text=True, timeout=30,
        )
    except FileNotFoundError:
        raise UnifiError("unifly not installed")
    except subprocess.TimeoutExpired:
        raise UnifiError("unifly timed out")
    if result.returncode != 0:
        raise UnifiError(result.stderr.strip() or "unifly returned non-zero")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        raise UnifiError("unifly did not return JSON")


def _records(payload):
    # unifly may wrap results in {"data": [...]} or return a bare list.
    if isinstance(payload, dict):
        return payload.get("data", [])
    return payload or []


def _normalize(item):
    return {
        "mac": (item.get("mac") or "").lower() or None,
        "ip": item.get("ip") or item.get("fixed_ip") or item.get("address"),
        "name": item.get("name") or item.get("hostname") or item.get("display_name"),
    }


def fetch_unifi_clients():
    # VERIFY exact subcommand with `unifly --help`; adjust args if needed.
    return [_normalize(c) for c in _records(_run_unifly(["client", "list", "--json"]))]


def fetch_unifi_reservations():
    # VERIFY exact subcommand with `unifly --help`; adjust args if needed.
    return [_normalize(r) for r in _records(_run_unifly(["dhcp", "reservation", "list", "--json"]))]


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
    res_by_mac = {r["mac"]: r["ip"] for r in reservations if r.get("mac")}
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
                f"{c.get('name') or c['mac']} has dynamic lease {ip} inside static range {lo}-{hi}"))
    return findings


def find_undocumented_clients(inventory, clients):
    known = inventory_ips(inventory)
    return [
        Finding(ADVISORY, "undocumented-client",
                f"UniFi client {c.get('name') or c['mac']} ({c['ip']}) not in inventory")
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
```

- [ ] **Step 4: Run the full test suite**

Run: `pytest tests/test_ip_inventory.py -v`
Expected: PASS (all tests from Tasks 1–5).

- [ ] **Step 5: Verify the unifly subcommands**

Run: `unifly --help` (and any relevant `unifly <group> --help`) to confirm the real subcommand names for listing clients and DHCP reservations and their JSON flag. If they differ from the guessed `client list --json` / `dhcp reservation list --json`, update the two `# VERIFY` lines in `fetch_unifi_clients` / `fetch_unifi_reservations` accordingly. Then run `unifly <confirmed client cmd>` once and confirm `_normalize` maps the real field names (`mac`, `ip`/`fixed_ip`, `name`/`hostname`); extend `_normalize` if the payload uses other keys.
Expected: both fetchers return non-empty lists of `{mac, ip, name}` dicts against the live controller.

- [ ] **Step 6: Commit**

```bash
git add scripts/ip_inventory.py tests/test_ip_inventory.py
git commit -m "feat(network): add UniFi reconcile checks, adapter, and CLI entrypoint"
```

---

### Task 6: group_vars/all directory + author the inventory

**Files:**
- Delete/Move: `group_vars/all.yml` → `group_vars/all/connection.yml`
- Create: `group_vars/all/network_inventory.yml`

**Interfaces:**
- Consumes: the schema used by `load_inventory` and all checks (keys: `networks.main.{static,dhcp_pool,personal}`, `hosts[].{name,ip,mac,assignment,managed_by,dns,notes}`).
- Produces: the live inventory consumed by `cmd_check`/`cmd_reconcile`/`cmd_next`.

- [ ] **Step 1: Convert `group_vars/all.yml` into a directory**

Ansible merges every file in `group_vars/all/`. Move the existing file verbatim:

```bash
mkdir -p group_vars/all
git mv group_vars/all.yml group_vars/all/connection.yml
```

- [ ] **Step 2: Verify Ansible still loads the same vars**

Run: `ansible -i hosts all -m debug -a "var=ansible_user" --limit tika` (or any host) — or `task syntax`.
Expected: `ansible_user` resolves to `ansible` exactly as before; `task syntax` passes. (This proves the file → directory move did not drop any variable.)

- [ ] **Step 3: Author `group_vars/all/network_inventory.yml`**

Translate `docs/guides/ip-address-map.md` verbatim. Hosts the map annotates as "DHCP reservation (MAC: …)" become `assignment: reservation` with that MAC; Proxmox nodes and statically-addressed LXCs become `assignment: static` (`mac: null`); the MacBook becomes `dynamic-noted`. Include `.16` (uptime-kuma), `.17` (caddy), and `.24` (arr), which the map currently omits but pi-hole/Caddy reference. Set `dns` only for hosts that have a *direct* A record pointing at their own IP in `pihole_local_hosts` (service names fronted by Caddy belong to Caddy, not to host DNS).

```yaml
---
# Structured network inventory — source of truth for infrastructure.
# Phase 1: consumed by scripts/ip_inventory.py for drift detection.
# Phase 2 (future): render pihole_local_hosts / caddy_services / ip-address-map.md from this.
network_inventory_version: 1

networks:
  main:
    cidr: 192.168.233.0/24
    dhcp_pool: ["192.168.233.51", "192.168.233.220"]
    static: ["192.168.233.1", "192.168.233.50"]
    personal: ["192.168.233.240", "192.168.233.250"]
  iot:
    cidr: 192.168.40.0/24
    dhcp_pool: ["192.168.40.10", "192.168.40.200"]
  storage:
    cidr: 192.168.220.0/24

hosts:
  - {name: gateway,       ip: 192.168.233.1,  mac: null,                assignment: static,        managed_by: unifi,     dns: [],                       notes: "UniFi Express 7 — router/controller"}
  - {name: pi-hole,       ip: 192.168.233.3,  mac: null,                assignment: static,        managed_by: ansible,   dns: [pi-hole.tlesh.xyz],      notes: "Primary DNS (on tika)"}
  - {name: ansalon,       ip: 192.168.233.6,  mac: "6c:1f:f7:76:99:8f", assignment: reservation,   managed_by: manual,    dns: [ansalon.tlesh.xyz],      notes: ""}
  - {name: tika,          ip: 192.168.233.7,  mac: null,                assignment: static,        managed_by: terraform, dns: [tika.tlesh.xyz],         notes: "Proxmox node"}
  - {name: bupu,          ip: 192.168.233.8,  mac: null,                assignment: static,        managed_by: terraform, dns: [bupu.tlesh.xyz],         notes: "Proxmox node"}
  - {name: sturm,         ip: 192.168.233.9,  mac: null,                assignment: static,        managed_by: terraform, dns: [sturm.tlesh.xyz],        notes: "Proxmox node"}
  - {name: kaz,           ip: 192.168.233.10, mac: "bc:24:11:10:00:01", assignment: reservation,   managed_by: ansible,   dns: [kaz.tlesh.xyz],          notes: "Docker host VM (on tika)"}
  - {name: jetkvm,        ip: 192.168.233.11, mac: "44:b7:d0:e7:82:89", assignment: reservation,   managed_by: manual,    dns: [jetkvm.tlesh.xyz],       notes: "KVM-over-IP"}
  - {name: plex,          ip: 192.168.233.12, mac: null,                assignment: static,        managed_by: ansible,   dns: [plex.tlesh.xyz],         notes: "Media server (on sturm)"}
  - {name: printer,       ip: 192.168.233.15, mac: "54:35:30:68:19:38", assignment: reservation,   managed_by: manual,    dns: [],                       notes: "Brother printer"}
  - {name: uptime-kuma,   ip: 192.168.233.16, mac: null,                assignment: static,        managed_by: ansible,   dns: [],                       notes: "Fronted by Caddy (.17); VERIFY actual IP/assignment"}
  - {name: caddy,         ip: 192.168.233.17, mac: null,                assignment: static,        managed_by: ansible,   dns: [caddy.tlesh.xyz],        notes: "Reverse proxy; fronts most service hostnames"}
  - {name: minecraft,     ip: 192.168.233.19, mac: "bc:24:11:13:00:01", assignment: reservation,   managed_by: ansible,   dns: [],                       notes: "Minecraft server VM"}
  - {name: tailscale,     ip: 192.168.233.21, mac: "ea:31:e7:19:05:63", assignment: reservation,   managed_by: ansible,   dns: [tailscale.tlesh.xyz],    notes: "Subnet router (on tika)"}
  - {name: glance,        ip: 192.168.233.22, mac: null,                assignment: static,        managed_by: ansible,   dns: [],                       notes: "RETIRING — migrated to kaz (.10); decommission after kaz verified"}
  - {name: netdata,       ip: 192.168.233.23, mac: null,                assignment: static,        managed_by: ansible,   dns: [],                       notes: "Monitoring (on sturm)"}
  - {name: arr,           ip: 192.168.233.24, mac: null,                assignment: static,        managed_by: ansible,   dns: [arr.tlesh.xyz],          notes: "*arr stack; VERIFY actual IP/assignment"}
  - {name: macbook,       ip: 192.168.233.25, mac: null,                assignment: dynamic-noted, managed_by: manual,    dns: [],                       notes: "Personal device — do not assign to infrastructure"}
  - {name: claude-code,   ip: 192.168.233.26, mac: null,                assignment: static,        managed_by: terraform, dns: [],                       notes: "Claude Code LXC (on tika, vm_id 125)"}
  - {name: drizzt,        ip: 192.168.233.27, mac: "6c:6e:07:1e:39:74", assignment: reservation,   managed_by: manual,    dns: [],                       notes: ""}
  - {name: magius,        ip: 192.168.233.29, mac: "d0:37:45:cf:ce:4c", assignment: reservation,   managed_by: manual,    dns: [],                       notes: ""}
  - {name: kaladin,       ip: 192.168.233.30, mac: "c4:35:d9:89:4c:b4", assignment: reservation,   managed_by: manual,    dns: [],                       notes: ""}
  - {name: kvothe,        ip: 192.168.233.31, mac: "54:bf:64:2e:b2:51", assignment: reservation,   managed_by: manual,    dns: [],                       notes: ""}
  - {name: homeassistant, ip: 192.168.233.35, mac: "b8:27:eb:75:3a:e3", assignment: reservation,   managed_by: manual,    dns: [homeassistant.tlesh.xyz], notes: "Raspberry Pi — pi-hole currently points HA DNS at .125 (DRIFT, resolve in Task 8)"}
  - {name: solinari,      ip: 192.168.233.200, mac: "00:11:32:8e:27:e1", assignment: reservation,  managed_by: manual,    dns: [],                       notes: "UGREEN NAS — legacy, stays in dynamic range (Time Machine + iSCSI)"}
  # UniFi network gear — recorded so reconcile does not flag them as undocumented
  - {name: chimney-ap,    ip: 192.168.233.139, mac: null,               assignment: dynamic-noted, managed_by: unifi,     dns: [],                       notes: "UniFi AC Mesh AP"}
  - {name: usw-flex-mini, ip: 192.168.233.185, mac: null,               assignment: dynamic-noted, managed_by: unifi,     dns: [],                       notes: "UniFi switch"}
  - {name: usw-pro-max-16, ip: 192.168.233.188, mac: null,              assignment: dynamic-noted, managed_by: unifi,     dns: [],                       notes: "UniFi core switch"}
```

- [ ] **Step 4: Validate the inventory parses and yamllint passes**

Run: `python -c "import sys; sys.path.insert(0,'scripts'); import ip_inventory as m; print(len(m.load_inventory(m.INVENTORY_PATH)['hosts']), 'hosts')"`
Expected: prints the host count (e.g. `27 hosts`), no traceback.
Run: `yamllint group_vars/all/network_inventory.yml`
Expected: no errors (fix line-length/spacing if flagged).

- [ ] **Step 5: Commit**

```bash
git add group_vars/all/connection.yml group_vars/all/network_inventory.yml
git rm --cached group_vars/all.yml 2>/dev/null || true
git commit -m "feat(network): add structured inventory; move group_vars/all to a directory"
```

---

### Task 7: Wire `task` commands + CI gate

**Files:**
- Modify: `Taskfile.yml`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `scripts/ip_inventory.py` CLI (`check`, `reconcile`, `next`).
- Produces: `task ip:check`, `task ip:reconcile`, `task ip:next` and a CI step running `ip:check`.

- [ ] **Step 1: Add tasks to `Taskfile.yml`**

Match the existing task style in the file. Add:

```yaml
  ip:check:
    desc: "Repo-internal IP/DNS drift check (no network, CI-safe)"
    cmds:
      - python scripts/ip_inventory.py check

  ip:reconcile:
    desc: "IP drift check + live UniFi reconcile (local only)"
    cmds:
      - python scripts/ip_inventory.py reconcile

  ip:next:
    desc: "Next free static IP, or check one: task ip:next -- 192.168.233.42"
    cmds:
      - python scripts/ip_inventory.py next {{.CLI_ARGS}}
```

- [ ] **Step 2: Verify the tasks run**

Run: `task ip:check`
Expected: prints a drift report and exits non-zero only if a BLOCKING finding exists.
Run: `task ip:next`
Expected: prints a free static IP (UniFi warning to stderr is fine if not authenticated).

- [ ] **Step 3: Add the CI gate**

In `.github/workflows/ci.yml`, in the job that already has Python/PyYAML available (or add a `pip install pyyaml` step), add after the existing checks:

```yaml
      - name: IP inventory drift check
        run: python scripts/ip_inventory.py check
```

- [ ] **Step 4: Lint the workflow and Taskfile**

Run: `task --list | grep '^\* ip:'` (confirms the three tasks registered) and `yamllint .github/workflows/ci.yml Taskfile.yml`
Expected: three `ip:` tasks listed; no yamllint errors.

- [ ] **Step 5: Commit**

```bash
git add Taskfile.yml .github/workflows/ci.yml
git commit -m "feat(network): wire ip:check/reconcile/next tasks and CI gate"
```

---

### Task 8: Integration run + drift hand-off

**Files:**
- Modify: `group_vars/all/network_inventory.yml` (only to fix confirmed-correct values)
- Modify: `roles/pi-hole/defaults/main.yml` / `roles/caddy/defaults/main.yml` (only if a record is confirmed wrong)

**Interfaces:**
- Consumes: the full tool + live UniFi.
- Produces: a clean `task ip:check` (no BLOCKING) and a written list of decisions requiring the user.

- [ ] **Step 1: Run the repo check and capture findings**

Run: `task ip:check`
Expected: with the inventory authored in Task 6, the previously "missing" service IPs (`.16`, `.17`, `.24`) are now documented and produce no findings. Any remaining BLOCKING finding is a genuine conflict — most likely `homeassistant` (pi-hole maps it to `.125`, inventory says `.35`).

- [ ] **Step 2: Run the live reconcile**

Run: `task ip:reconcile`
Expected: surfaces (a) the MacBook's `dynamic-in-static` lease at `.25` (the original incident), (b) any `reservation` host whose UniFi reservation is missing/mismatched, (c) advisory undocumented clients.

- [ ] **Step 3: Do NOT guess — hand off the decisions**

For each remaining BLOCKING finding, these require the user's network decision (record them, do not silently pick):
- **homeassistant `.35` vs `.125`:** is HA meant to be the reserved `.35`, or accept the current `.125`? Resolution is either (a) create the `.35` reservation in UniFi + leave pi-hole/inventory at `.35`, or (b) change inventory + pi-hole to `.125`.
- **MacBook `.25` dynamic-in-static:** either shrink UniFi's static range / move the DHCP pool boundary so `.1–.50` is truly reserved, or add a reservation. This is the root cause of the original incident.
- **Any reservation mismatch:** confirm whether UniFi or the inventory holds the correct IP.

Present these to the user. Apply only the fixes they confirm. After applying confirmed fixes, re-run `task ip:check` and confirm it exits zero (no BLOCKING).

- [ ] **Step 4: Commit any confirmed fixes**

```bash
git add -A
git commit -m "fix(network): reconcile inventory/pi-hole drift per review"
```

---

## Self-Review

**Spec coverage:**
- Inventory file in group_vars → Task 6. ✓
- `check` (CI-safe, repo-internal) → Task 3 + Task 7 CI step. ✓
- `reconcile` (live UniFi, graceful degrade) → Task 5. ✓
- `next` pre-assignment helper → Task 4. ✓
- Hybrid authority (reservation/static/dynamic-noted) → Task 5 checks + Task 6 schema. ✓
- Blocking/Advisory output format → Task 1 + severity rules in Tasks 3/5. ✓
- group_vars/all file→dir migration → Task 6. ✓
- Detects the five known drifts + `.25` incident → Tasks 3/5, verified in Task 8. ✓
- Non-goals (read-only, no daemon, Phase 2 sketched) → respected throughout. ✓

**Placeholder scan:** The two `# VERIFY` markers in Task 5 (unifly subcommands) and the `VERIFY` notes on `.16`/`.24` in Task 6 are deliberate execution-time confirmations against live systems, each with an explicit verification step — not unfinished plan content. No other TBDs.

**Type consistency:** `Finding(severity, category, message)` used identically everywhere. UniFi dicts are normalized to `{mac, ip, name}` by `_normalize` before any pure check consumes them. `cmd_next`'s dependency on `gather_unifi_used` (defined Task 5) is called out in Task 4 with an interim stub. `networks.main.static` is a 2-element `[lo, hi]` list everywhere it's read.
