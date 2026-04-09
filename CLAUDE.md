# AI Instructions (Claude & Gemini)

Refined homelab infrastructure management (Proxmox, Terraform, Ansible).

## Core Principles
- **Stability & Uptime**: Prioritize absolute reliability.
- **KISS**: Simplicity over engineering.
- **Doppler First**: All secrets come from Doppler. No local vaults.

## Entry Points & Documentation
Specialized rules:
- **[Ansible](file:///.claude/rules/ansible.md)**: Role patterns, chown rules, linting.
- **[Terraform](file:///.claude/rules/terraform.md)**: Resource naming, providers, Task commands.
- **[Gitflow](file:///.claude/rules/gitflow.md)**: Branching strategy, PR reviews, CI.
- **[Tooling](file:///.claude/rules/tools.md)**: Doppler, Context7, RTK, CLI flags.
- **[Memory](file:///MEMORY.md)**: Architectural decisions and tech debt history.
- **[Issue Tracking](file:///AGENTS.md)**: `bd` (beads) command reference and session landing rules.

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
