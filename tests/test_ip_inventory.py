import textwrap

from ip_inventory import (
    ADVISORY,
    BLOCKING,
    Finding,
    format_report,
    has_blocking,
    load_inventory,
    parse_caddy_services,
    parse_pihole_records,
)


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
