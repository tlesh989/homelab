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

## Git Workflow (gitnow)

```bash
feature <name>   # Start feature branch
bugfix <name>    # Start bugfix branch
hotfix <name>    # Start hotfix branch
chore/<name>    # Chore: git checkout -b chore/<name>

# Pre-branch (replaces fetch+checkout+pull):
/clean_gone       # Prune deleted remotes
move dev          # Switch to dev with autostash
pull              # Rebase pull
```

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