# Agent Instructions

Personal homelab IaC: Terraform (Proxmox LXC/VM provisioning) + Ansible (configuration). Secrets via Doppler. Issue tracking via **bd** (beads).

## Core Principles

- **Stability & Uptime**: Prioritize absolute reliability.
- **KISS**: Minimum change that solves the problem. No speculative features or abstractions.
- **Doppler First**: All secrets come from Doppler. No local vaults.
- **Efficiency**: Do not re-read files already read in this session unless the file may have changed. Prefer targeted edits over full rewrites.
- **Think First**: State assumptions before touching infra. Ask when unclear — wrong assumptions break live services.

## Rules & Standards

Source of truth is `.claude/rules/` (Claude Code auto-loads it); `.agents/rules/` symlinks to the same files.

- **[Code Quality](.claude/rules/code-quality.md)**: Think first, surgical changes, goal-driven execution.
- **[Ansible](.claude/rules/ansible.md)**: Role patterns, chown rules, linting, symmetric package removal.
- **[Terraform](.claude/rules/terraform.md)**: Resource naming (`snake_case`/`kebab-case`), providers, Task commands.
- **[Shell](.claude/rules/shell.md)**: Bash strict mode, timeouts, exit-code gating.
- **[Docker](.claude/rules/docker.md)**: Image tags, Watchtower, service checklist.
- **[Gitflow](.claude/rules/gitflow.md)**: Branching strategy, PR reviews, CI.
- **[Tooling](.claude/rules/tools.md)**: Doppler, Context7, RTK, CLI flags.
- **[Public Hostnames](.claude/rules/public-hostnames.md)**: Never post public-domain (`.net`) hostnames in PRs, comments, commits, or code.
- **[RTK](.claude/rules/rtk.md)**: Token-optimized command instructions.
- **[Memory](MEMORY.md)**: Architectural decisions and tech debt history.
- **[Gotchas](GOTCHAS.md)**: Symptom → cause → fix for things that bit us. Check it when debugging; add an entry when you learn one.

## Dev Commands

```bash
mise install              # Install pinned tool versions (terraform, task, direnv, gh, bun, uv, ansible-core, ansible-lint, yamllint)
task check                # Dry-run verify all hosts
task syntax && task lint  # Fast linting/syntax checks
task ping                 # Verify host connectivity
doppler run -- <cmd>      # Run any command with secrets
```

Tool versions are pinned in `mise.toml` and shared across dev machines and the claude-code LXC — run `mise install`
after cloning. `task` remains the task runner (Taskfile.yml); mise only manages tool versions.
Ansible itself is installed via mise's `pipx:` backend (needs `uv`, also mise-managed) —
there is no separate apt/pip install step for ansible.

## Sources of Truth

Each fact lives in one place. Check it before stating a fact — never answer from memory alone.

- **Current state** (IPs, VLANs, SSIDs, devices, host roles): `docs/guides/ip-address-map.md`, `hosts`,
  `terraform/*.tf`, `group_vars/`. If it's not there, check live (`doppler run -- unifly ...`,
  `pvesh get /cluster/resources --type vm`) and add it to the doc. VM/LXC node placement migrates — always check live.
- **History and open work**: beads. Before starting a task, `bd search <topic>` for prior issues and how they were solved.
  Close issues with a reason that says what changed and which PR.
- **Conventions**: `.claude/rules/`. Agent memory holds only preferences and lessons not written elsewhere —
  when a memory and the repo disagree, the repo wins; fix or delete the memory.

## Issue Tracking

```bash
bd search <topic>              # Prior work on a topic — check before starting
bd onboard                     # Initial setup
bd ready --json                # Find work
bd update <id> --claim         # Claim atomically
bd close <id> --reason "Done"  # Complete
bd dolt push && git push       # MUST push before ending session
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
rm -rf directory       # NOT: rm -r directory
ssh -o BatchMode=yes   # Fail instead of prompt
apt-get -y             # Auto-confirm
```

## Definition of Done

1. **Verify**: Run `task syntax`, `task lint`, and `task -d terraform test` (TF).
2. **Review**: CodeRabbit reviews the PR automatically on GitHub — no local run. Address its comments with `/fix-pr`.
3. **Commit**: Use `feat:`, `fix:`, or `chore:` prefixes.
4. **Land the plane**:
   1. File remaining work: `bd create "title" --json`
   2. Close completed work: `bd close <id> --reason "Done" --json`
   3. Push: `git pull --rebase && bd dolt push && git push`
   4. Verify push succeeded — resolve conflicts if any. Work is NOT complete until `git push` succeeds.
