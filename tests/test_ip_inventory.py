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
