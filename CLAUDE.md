# AI Instructions (Claude & Gemini)

Refined homelab infrastructure management (Proxmox, Terraform, Ansible).

## Core Principles

- **Stability & Uptime**: Prioritize absolute reliability.
- **KISS**: Simplicity over engineering.
- **Doppler First**: All secrets come from Doppler. No local vaults.
- **Efficiency**: Do not re-read files already read in this session unless the file may have changed. Prefer targeted edits over full rewrites.

## Entry Points & Documentation

Specialized rules:

- **[Ansible](.claude/rules/ansible.md)**: Role patterns, chown rules, linting.
- **[Terraform](.claude/rules/terraform.md)**: Resource naming, providers, Task commands.
- **[Gitflow](.claude/rules/gitflow.md)**: Branching strategy, PR reviews, CI.
- **[Tooling](.claude/rules/tools.md)**: Doppler, Context7, RTK, CLI flags.
- **[RTK](.claude/rules/rtk.md)**: Token-optimized command instructions.
- **[Memory](MEMORY.md)**: Architectural decisions and tech debt history.
- **[Issue Tracking](AGENTS.md)**: `bd` (beads) command reference and session landing rules.

## Primary Commands

```bash
task check                  # Dry-run verify all hosts
task syntax && task lint    # Fast linting/syntax checks
task ping                   # Verify host connectivity
doppler run -- ...          # Run any command with secrets
```

## Definition of Done

1. **Verify**: Run `task syntax`, `task lint`, and `task test` (TF).
2. **Review**: Run `coderabbit review` if changing logic.
3. **Commit**: Use `feat:`, `fix:`, or `chore:` prefixes.
4. **Push**: Work is NOT complete until `git push` succeeds (see `AGENTS.md`).
