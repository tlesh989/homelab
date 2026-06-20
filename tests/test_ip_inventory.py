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
