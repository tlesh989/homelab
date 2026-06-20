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
