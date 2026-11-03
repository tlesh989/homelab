# Tooling & Security Conventions

- **Tool versions**: Pinned in `mise.toml` (terraform, task, python, uv, ansible-core, ansible-lint, yamllint, …) — the one source for dev machines, the claude-code LXC and CI (`jdx/mise-action`). Run `mise install` after cloning. `task` stays the task runner. Ansible is installed via mise's `pipx:` backend, not apt/pip.
- **Python deps**: `truenas-api-client` is installed into ansible's own venv via `with` on `pipx:ansible-core` (ansalon runs modules locally with `ansible_playbook_python`). `requirements.txt` is only for the `.venv` used by `scripts/ip_inventory.py` and its tests. After changing `with`, run `mise install -f pipx:ansible-core` — a plain `mise install` skips it when the version is unchanged.
- **Secrets**: Use `doppler run -- <command>`. NO local vaults.
- **Docs**: Proactively use Context7 for SDK/API references.
- **Shell**: Use `gh` for GitHub, prefix tools with `rtk` where applicable. Run `task` for operations.
- **Issues**: Use `bd` (beads) for task tracking. See `AGENTS.md`.
- **Claude**: Project config in `.claude/settings.json`. Hooks handle safety/linting invisibly.
