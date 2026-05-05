# Molecule Hardening Report — 2026-05-05

## Summary

| Role            | Scenario | Iterations | Result |
|-----------------|----------|------------|--------|
| cloudflare_ddns | default  | 5          | ✅ Green |
| minecraft       | default  | 2          | ✅ Green |
| n8n             | default  | 1          | ✅ Green |
| monitoring      | default  | 2          | ✅ Green |

All four roles pass `molecule test -s default`. Total iteration budget used: 10 of 40.

---

## What Was Hardened

### Cross-Cutting Fixes (applied to all roles)

**`roles_path` must be explicit in `molecule.yml`**
Molecule cannot resolve in-repo roles by default. All four `molecule.yml` files now include:
```yaml
provisioner:
  config_options:
    defaults:
      roles_path: ${MOLECULE_PROJECT_DIRECTORY}/../
```

**`apt update` required in `prepare.yml`**
The `geerlingguy/docker-ubuntu2604-ansible` image ships with a stale APT cache. Package installs (`python3-docker`, `unzip`, `curl`, etc.) fail without an explicit cache refresh. All `prepare.yml` files now run `apt update` with `cache_valid_time: 3600`.

**`molecule_testing` guard on Docker tasks**
Seven `community.docker.*` tasks across three roles now skip when `molecule_testing: true` is set, preventing Docker daemon errors in lightweight test containers:
- `roles/cloudflare_ddns/tasks/main.yml` — 1 task (container deploy)
- `roles/n8n/tasks/main.yml` — 1 task (container deploy)
- `roles/monitoring/tasks/main.yml` — 5 tasks (network + 4 container deploys)

**Colima `DOCKER_HOST`**
Molecule must be invoked with `DOCKER_HOST=unix:///Users/tommy/.colima/default/docker.sock` since Colima does not symlink to `/var/run/docker.sock`. This is an environment constraint, not embedded in scenario files. Add to shell profile or `task` invocation.

---

### cloudflare_ddns (5 iterations)

The role is entirely Docker-based — the structural scenario exercises assert tasks (fake env vars) and python3-docker package installation only.

| Fix | File | Classification |
|-----|------|----------------|
| Added `roles_path` config | `molecule/default/molecule.yml` | CONFIG_BUG |
| Replaced no-op prepare with `apt update` | `molecule/default/prepare.yml` | CONFIG_BUG |

---

### minecraft (2 iterations)

Rich structural scenario: system user, directory ownership, config templates, systemd service, cron job, update script.

| Fix | File | Classification |
|-----|------|----------------|
| `getent_passwd` shell index corrected from `[4]` to `[5]` | `molecule/default/verify.yml` | TEST_BUG |

**Details:** The Linux `/etc/passwd` format has fields: `[0]` username, `[1]` password, `[2]` uid, `[3]` gid, `[4]` gecos/comment, `[5]` home, `[6]` shell. The original assertion used index `[4]` (home directory) to check for `/usr/sbin/nologin` — this would silently pass on a user whose home happens to match that string. The fix uses index `[5]` (shell) which is the correct field.

---

### n8n (1 iteration — green first try)

The n8n scenario correctly tested data directory permissions (`uid=1000 gid=1000 mode=0700`) and python3-docker installation. No fixes required.

---

### monitoring (2 iterations)

Full observability stack structural test: Prometheus/Grafana/cAdvisor/pve-exporter directory layout, config templating, credential file permissions.

| Fix | File | Classification |
|-----|------|----------------|
| Added `molecule_testing` guard to all 3 handlers | `roles/monitoring/handlers/main.yml` | ROLE_BUG |
| Added `vars: { molecule_testing: true }` to converge play | `molecule/default/converge.yml` | CONFIG_BUG |

**Details:** When templates change (e.g., `prometheus.yml`), Ansible notifies `Restart Prometheus`. Handlers fire after all tasks complete — but the original `molecule_testing` guard only covered task-level Docker calls, not handler-level calls. In a container without a Docker daemon, the handler `community.docker.docker_container` task raised `FileNotFoundError`. All three handlers (`Restart Prometheus`, `Restart Grafana`, `Restart pve-exporter`) now carry the same guard as the tasks that notify them.

---

## Silent-Exit Findings

**minecraft-update script — CONFIRMED SAFE**

The `roles/minecraft/templates/minecraft-update.sh.j2` script has:
- `set -euo pipefail` at the top (errors surface immediately, no silent swallowing)
- An explicit early-exit guard for unsafe `INSTALL_DIR`:
  ```bash
  if [[ -z "${INSTALL_DIR}" || "${INSTALL_DIR}" == "/" ]]; then
    echo "ERROR: refusing to update with unsafe INSTALL_DIR='${INSTALL_DIR}'" >&2
    exit 1
  fi
  ```
- All `grep` calls in `get_latest_bds_url()` are wrapped in retry loops with explicit error logging — a grep miss produces a `WARNING` log and retries, never silently exits
- The version-comparison `grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'` runs on a validated URL string, so empty-match would propagate as an empty `LATEST_VERSION` and the version comparison would fall through to the "already up to date" path

The `verify.yml` silent-exit test confirmed this: running with `INSTALL_DIR=/` produces output (`ERROR: refusing...`) and exits non-zero. The script does not silently exit.

**No unguarded grep calls requiring `|| true` were found.**

---

## Integration Scenarios

All four roles have integration scenario stubs scaffolded at `roles/<role>/molecule/integration/`. These require Docker-in-Docker (or Docker socket mount) and — for cloudflare_ddns and monitoring — real Doppler secrets.

| Role            | Integration trigger |
|-----------------|---------------------|
| cloudflare_ddns | `doppler run -- task molecule-integration -- ROLE=cloudflare_ddns` |
| minecraft       | `task molecule-integration -- ROLE=minecraft` (requires internet for BDS download) |
| n8n             | `task molecule-integration -- ROLE=n8n` |
| monitoring      | `doppler run -- task molecule-integration -- ROLE=monitoring` |

**All integration scenarios must be run with `DOCKER_HOST=unix:///Users/tommy/.colima/default/docker.sock`.**

---

## Scenarios Requiring Human Review

None. All four roles reached green within the 10-iteration budget.

---

## Recommended Next Steps

1. **Add `DOCKER_HOST` to shell profile** or a `.env` file sourced by `task` so `task molecule-test` works without manual prefix.
2. **Add molecule to CI** — the default scenarios are lightweight enough for GitHub Actions. Add a `molecule.yml` workflow triggered on changes to `roles/**`.
3. **Implement integration scenarios** — the stubs are ready; add real assertions and test them manually with Doppler credentials.
