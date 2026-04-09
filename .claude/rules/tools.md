# Tooling & Security Conventions

- **Secrets**: Use `doppler run -- <command>`. NO local vaults.
- **Docs**: Proactively use Context7 for SDK/API references.
- **Shell**: Use `gh` for GitHub, prefix tools with `rtk` where applicable. Run `task` for operations.
- **Issues**: Use `bd` (beads) for task tracking. See `AGENTS.md`.
- **Claude**: Project config in `.claude/settings.json`. Hooks handle safety/linting invisibly.
