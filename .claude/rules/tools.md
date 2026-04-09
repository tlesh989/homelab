# Tooling & Security Conventions

## Doppler (Secrets Management)

- **Source of Truth**: All secrets MUST come from Doppler.
- **No Local Vaults**: `vars/vault.yml` and `.vault_pass` have been removed. Do NOT reintroduce them.
- **Injection**: Use `doppler run -- <command>` for local execution with secrets.

## MCP Tools

- **Context7**: Use proactively for docs, API references, and provider schemas (Ansible modules, Terraform providers).
- **GitHub CLI**: Use `gh` for all GitHub operations.
- **RTK**: Installed globally. Prefix shell commands with `rtk` for token savings/analytics.

## Repository Tools

- **beads (bd)**: Used for issue tracking. See `AGENTS.md` for full command list.
- **Task**: Orchestrator for all operations. Run `task` to list available targets.

## Claude Configuration

- **Settings**: Project-level settings live in `.claude/settings.json`.
- **Hooks**: PreToolUse blocks secret exposure; PostToolUse automated linting/formatting.
