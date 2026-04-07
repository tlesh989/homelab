# AI Instructions (Claude & Gemini)

This file provides guidance to Claude Code (claude.ai/code) and Gemini CLI when working with code in this repository.

## Project Overview

This is a homelab infrastructure repo using Terraform (Proxmox provider), Ansible roles, and Doppler for secrets. Primary languages are YAML (Ansible), HCL (Terraform), and Markdown. Always check existing patterns before creating new files.

- **Infrastructure:** Proxmox VE hosting LXC containers and VMs across nodes (e.g., `bupu`, `sturm`, `tika`).
- **Provisioning:** Terraform using the `bpg/proxmox` provider — see `terraform/CLAUDE.md` for Terraform-specific guidance.
- **Configuration:** Ansible playbooks and roles for services like Tailscale, Plex, Pi-hole, and Glance.
- **Secret Management:** [Doppler](https://www.doppler.com/) for secret injection.
- **Automation:** [Task](https://taskfile.dev/) for orchestrating operations.
- **Environment:** MacBook Air M4 (Arm64).

## Engineering Standards

- **Stability & Uptime**: Prioritize system reliability above all.
- **KISS**: Avoid over-engineering.
- **Doppler First**: All secrets come from Doppler. Never hardcode or use local vault files.
- **Proactive SRE**: Anticipate networking, IAM, and observability needs.
- **Source Control**: Do not stage or commit changes unless specifically requested. Use standard commit messages (`feat:`, `fix:`, `chore:`, etc.).

## Common Commands

```bash
task                        # List all available tasks
task reqs                   # Install Ansible Galaxy dependencies
task proxmox                # Deploy Proxmox hypervisors
task tailscale              # Deploy Tailscale subnet router
task plex                   # Deploy Plex media server
task glance                 # Deploy Glance dashboard
task check                  # Dry-run check mode for ALL hosts
task syntax                 # Check playbook syntax
task lint                   # Run ansible-lint
task ping                   # Test connectivity to all hosts

# Bootstrap a new LXC (first-time only — creates ansible service account)
# Doppler sets SSH_USER=tommy locally, so must override with ansible_user=root
doppler run -- ansible-playbook -b bootstrap.yml --limit <hostname> --tags bootstrap -e "ansible_user=root"
```

## Architecture & Key Directories

- **Ansible**: `main.yml` master playbook. `group_vars/` for hierarchy. Custom roles in `roles/`.
- **Inventory**: `hosts` file.
- **Tailscale**: ACL/policy in `tailscale/`.
- **Terraform**: `terraform/` — see `terraform/CLAUDE.md`.
- **Docs**: Plans in `docs/plans/`.

> **Vault removed**: `vars/vault.yml` has been removed. Do NOT reintroduce it or use `vault_pass`, `decrypt`, or `encrypt` tasks — all secrets go through Doppler.

## Conventions

- **Naming**: Files/Folders: `kebab-case`.
- **Ansible**: Mandatory `name:` fields, use `loop`, review `become: true`. Always include `mode:` parameter (e.g., `mode: '0644'`) on tasks that create or copy files — required by ansible-lint.
- **General**: 2-space indentation, max 120 chars line length.
- **Shell filename loops**: Always use `find -print0 | while IFS= read -r -d "" f; do ...` — never plain `while read f` (breaks on spaces/special chars). **Bash-specific; ensure Bash is used (`#!/usr/bin/env bash`, `bash -lc`, or Ansible `executable: /bin/bash`).**
- **Service user file creation**: Any task or Ansible step creating dirs/files for a service user must include `chown -R <puid>:<pgid> <path>` immediately after.

## Gitflow & CI/CD

- **Working Branch**: `dev`. **Production Branch**: `main`.
- **NEVER** commit directly to `dev` or `main`. Always use `feature/*`, `bugfix/*`, `chore/*`, or `hotfix/*` branches, merged via PR.
- **Always create feature branches for changes** — never commit directly to `dev` or `main`. Branch from the correct base branch (usually `dev`).
- Before any changes: 1) verify your branch, 2) create a feature branch from `dev` if needed, 3) review existing patterns, 4) list your plan and wait for explicit approval before editing.
- **Automation**:
  - `ci.yml`: Runs on push/PR to `dev`/`main`. Runs Terraform `task ci` and Ansible syntax check (no Doppler, no vault).
  - `dev-to-main-pr.yml`: Auto-creates/updates PR from `dev` → `main` when `dev` is updated.
  - `tailscale.yml`: Syncs Tailscale ACLs.

## Code Editing Rules

- When using Edit with `replace_all`, verify substitutions don't collide with similarly-named variables (e.g., `users` vs `users_groups` or `users_ssh_exclusive`).
- Before removing or modifying references to files/resources, verify they actually exist. Do not assume a reference is dead without checking.

## Key Files to Keep in Sync

- `.github/copilot-instructions.md` — Update when conventions or CI checks change.

## Claude Configuration

- MCP server configurations go in `.claude/settings.json` (project-level) unless the user specifies global (`~/.claude/settings.json`).
- Cross-session memory (decisions, patterns, project state) lives in
  `~/.claude/projects/<encoded-repo-path>/memory/MEMORY.md`. Check it when resuming work or
  making architectural decisions.
- **Dotfiles/Claude config**: use `~/.claude-personal/` for personal config and `~/.claude/` for work. Always verify `CLAUDE_CONFIG_DIR` before writing config files.

## MCP Tool Usage

- **Context7**: Use proactively for docs, API references, module options, and provider schemas — Ansible modules, Terraform providers (`bpg/proxmox`, `hashicorp/*`), Doppler, Tailscale, or any library. Don't wait to be asked.
- **GitHub**: Use the `gh` CLI (not an MCP) for all GitHub operations.
- **MCP server setup**: Use Docker-based GitHub MCP, not the deprecated `@modelcontextprotocol/server-github`. Place MCP configs in `.claude/settings.json`, not `.claude/mcp.json`.

## Model-Specific Skills & Hooks

### Claude Code

- `/deploy <target>` — dry-run first, apply on confirmation.
- `/ship [message]` — commit, push, and open a PR against `dev`.
- `/new-service <name>` — scaffold Terraform LXC config + Ansible role skeleton.
- Hooks (PostToolUse): `yamllint` on `.yml/.yaml`, `terraform fmt` + `validate` on `.tf`, `ansible-lint` on `roles/**/*.yml`. PreToolUse blocks edits to `.vault_pass`, `.envrc`, `vars/vault.yml`, `*.tfvars`.
- Agents: `infra-reviewer` — pre-deploy review for Ansible/Terraform changes (idempotency, naming, secret hygiene).

## Behavior Rules

- **SSH auth failures**: Stop immediately and tell the user to unlock their SSH key via 1Password before retrying.
- **Before opening a PR**: Always run `coderabbit review --plain --base dev` on committed changes before creating a PR with `/ship`.
- **GitHub auth**: `gh` stores credentials in the macOS keychain — they persist across sessions and don't expire mid-session. Set up once with `gh auth login --git-protocol ssh`. Required PAT scopes: `repo`, `admin:org`, `workflow`. To verify: `gh auth status`.

## Verification (Definition of Done)

- **Ansible change**: `task syntax` passes, `task lint` passes, `task check` dry-run shows expected changes only.
- **New service scaffold**: `task check` passes, `task ping` confirms connectivity.
- **PR ready**: CI passes on GitHub, `coderabbit review` clean.

### Gemini CLI

- Uses the `Research -> Strategy -> Execution` lifecycle.
- Prioritizes `Taskfile.yml` for all execution.
- Respects `GEMINI.md` (symlinked to this file).

## RTK

RTK is installed globally — prefix shell commands with `rtk` for token savings. Run `rtk gain` for analytics, `rtk discover` for missed opportunities.

<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (90-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk vitest run          # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%)
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->