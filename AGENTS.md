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
- **[RTK](.claude/rules/rtk.md)**: Token-optimized command instructions.
- **[Memory](MEMORY.md)**: Architectural decisions and tech debt history.

## Dev Commands

```bash
mise install              # Install pinned tool versions (terraform, task, direnv, gh, bun, uv, ansible-core, ansible-lint)
task check                # Dry-run verify all hosts
task syntax && task lint  # Fast linting/syntax checks
task ping                 # Verify host connectivity
doppler run -- <cmd>      # Run any command with secrets
```

Tool versions are pinned in `mise.toml` and shared across dev machines and the claude-code LXC — run `mise install`
after cloning. `task` remains the task runner (Taskfile.yml); mise only manages tool versions.
Ansible itself is installed via mise's `pipx:` backend (needs `uv`, also mise-managed) —
there is no separate apt/pip install step for ansible.

## Issue Tracking

```bash
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

1. **Verify**: Run `task syntax`, `task lint`, and `task test` (TF).
2. **Review**: CodeRabbit reviews the PR automatically on GitHub — no local run. Address its comments with `/fix-pr`.
3. **Commit**: Use `feat:`, `fix:`, or `chore:` prefixes.
4. **Land the plane**:
   1. File remaining work: `bd create "title" --json`
   2. Close completed work: `bd close <id> --reason "Done" --json`
   3. Push: `git pull --rebase && bd dolt push && git push`
   4. Verify push succeeded — resolve conflicts if any. Work is NOT complete until `git push` succeeds.
