# Molecule Testing Design — 2026-05-05

## Overview

Add Molecule test coverage to the four homelab-owned Ansible roles that currently have none:
`cloudflare_ddns`, `minecraft`, `n8n`, `monitoring`.

## Decisions

| Question | Answer |
|---|---|
| Scenario depth | Hybrid: structural `default` (CI-safe) + `integration` (DinD, manual) |
| Secrets | Fake values injected via `molecule.yml` provisioner env |
| Execution | Local, in-session iteration loop; molecule installed into virtualenv first |
| Layout | Per-role, two scenarios each (Option 1 — mirrors vendored Galaxy roles) |

## Infrastructure

**`requirements-dev.txt`** (new file, separate from `requirements.txt`):

```
molecule
molecule-plugins[docker]
pytest-testinfra
ansible-core
```

**Taskfile targets** (added to `Taskfile.yml`):

```
task molecule-test ROLE=<role>         # default scenario
task molecule-integration ROLE=<role>  # integration scenario (DinD)
task molecule-test-all                 # default for all four roles
```

**Platform image**: `geerlingguy/docker-ubuntu2604-ansible` — has systemd, Python, sudo.

## Scenario Layout

```
roles/
  cloudflare_ddns/molecule/
    default/      # structural: files, templates, systemd unit
    integration/  # DinD: DNS update script execution
  minecraft/molecule/
    default/      # structural: dirs, user, configs, service, cron
    integration/  # DinD: real BDS download + service start
  n8n/molecule/
    default/      # structural: data dir permissions
    integration/  # DinD: container deploy + port check
  monitoring/molecule/
    default/      # structural: dirs with correct UIDs, templated configs
    integration/  # DinD: full Prometheus+Grafana+cAdvisor+pve-exporter stack
```

Each scenario contains: `molecule.yml`, `converge.yml`, `prepare.yml`, `verify.yml`, `cleanup.yml`.

**Fake secrets in `molecule.yml`**:

```yaml
provisioner:
  env:
    PUSHOVER_API_TOKEN: test-token
    PUSHOVER_USER_KEY: test-key
    PVE_TOKEN_ID: fake@pve!token
    PVE_TOKEN_SECRET: fakesecret
    MINECRAFT_OPERATOR_XUID: "1234567890123456"
```

## Four Coverage Areas

| Area | Mechanism |
|---|---|
| First-run install | `converge.yml` from clean container |
| Idempotent re-run | Molecule built-in `--check-idempotency` (free) |
| Upgrade path | `prepare.yml` writes prior state (e.g., old `.version` for minecraft) |
| Failure recovery | `verify.yml` testinfra assertions on error-path behavior |

## Silent-Exit Bug Class

Target: shell scripts using `set -euo pipefail` where `grep` returns 1 on no-match, aborting silently.

Primary candidate: `minecraft-update` cron script.

**Assertions in `verify.yml`**:

- Script produces stdout or stderr on any invocation (no silent exit)
- Any `grep` that can legitimately miss is guarded with `|| true` or explicit exit handling
- `set -euo pipefail` is present (surfaces errors rather than hiding them)

## Autonomous Iteration Loop

Per role, up to 10 iterations:

1. Run `molecule test -s default`
2. Parse failures → classify as `ROLE_BUG`, `TEST_BUG`, `CONFIG_BUG`, or `NEEDS_HUMAN`
3. Apply fix → re-run
4. At 10 iterations without green: mark `NEEDS_HUMAN` and move to next role

**Fix scope**: `roles/<role>/tasks/main.yml`, `roles/<role>/molecule/default/`, `roles/<role>/defaults/main.yml` only.

**NEEDS_HUMAN triggers**: image pull failure, real external API dependency, DinD privilege issue, architectural role change required.

## Final Report

Produced at `docs/molecule-hardening-report.md`. Includes:

- Per-role summary table (scenarios, iterations, result)
- What was hardened (specific fixes per role)
- Silent-exit findings
- Scenarios requiring human review (with recommended action)
- Integration scenario status (scaffolded, manual execution required)
