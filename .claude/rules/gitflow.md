# Git & CI/CD Conventions

## Branching Strategy

- **Working Branch**: `main`.
- **Protected Branch**: NEVER commit directly to `main`.
- **Feature Branches**: Use `feature/*`, `bugfix/*`, `chore/*`, or `hotfix/*`.
- **Merging**: Use PRs merged via GitHub UI.

## Workflow

1. Verify your current branch.
2. Create a feature branch from `main` if needed.
3. Review existing patterns and list your plan.
4. Obtain explicit approval before editing.
5. **PR Review**: Always run `coderabbit review --plain --base main` on committed changes before creating a PR with `/ship`.

## Automation

- **`ci.yml`**: Runs on push/PR to `main`. Executes Terraform `task ci` and Ansible syntax checks.
- **`tailscale.yml`**: Syncs Tailscale ACLs.
- **`renovate.json`**: Managed bot for dependency updates.
