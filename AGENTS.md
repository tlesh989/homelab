# Agent Instructions

Personal homelab IaC: Terraform (Proxmox LXC/VM provisioning) + Ansible (configuration). Secrets via Doppler. Issue tracking via **bd** (beads).

## Issue Tracking

```bash
bd onboard      # Initial setup
bd ready --json           # Find work
bd update <id> --claim   # Claim atomically
bd close <id> --reason "Done"  # Complete
bd dolt push && git push   # MUST push before ending session
```

## Dev Commands

```bash
task syntax && task lint  # Fast validation
task check               # Dry-run all hosts
task ping               # Test connectivity
doppler run -- <cmd>    # Inject secrets
```

## Rules & Standards

- **[Code Quality](.agents/rules/code-quality.md)**: Think first, surgical changes, goal-driven execution.
- **[Ansible](.agents/rules/ansible.md)**: Role patterns, chown rules, linting, symmetric package removal.
- **[Terraform](.agents/rules/terraform.md)**: Resource naming (`snake_case`/`kebab-case`), providers, Task commands.
- **[Gitflow](.agents/rules/gitflow.md)**: Branching strategy, PR reviews, CI.
- **[Tooling](.agents/rules/tools.md)**: Doppler, Context7, RTK, CLI flags.
- **[Docker](.agents/rules/docker.md)**: Image tags, Watchtower, service checklist.
- **[RTK](.agents/rules/rtk.md)**: Token-optimized command instructions.

## Skills Available

- `/deploy` — Run playbook with dry-run verification first (Recommended)
- `/diagnose` — Host/service connectivity, health, container status
- `/implement` — Full workflow: branch → design → implement → validate → PR
- `/new-host` — Bootstrap LXC: Terraform → Ansible → role deployment
- `/new-service` — Scaffold new service: Terraform LXC + Ansible role
- `/ship` — Commit, push, and open PR

## Non-Interactive Flags

```bash
cp -f source dest      # NOT: cp source dest
rm -rf directory     # NOT: rm -r directory
ssh -o BatchMode=yes # Fail instead of prompt
apt-get -y           # Auto-confirm
```

## Landing the Plane

1. File remaining work: `bd create "title" --json`
2. Run quality gates: `task syntax && task lint`
3. Close completed work: `bd close <id> --reason "Done" --json`
4. Push: `git pull --rebase && bd dolt push && git push`
5. Verify push succeeded — resolve conflicts if any.
