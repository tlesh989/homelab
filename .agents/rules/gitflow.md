# Git & CI/CD Conventions

## Branching Strategy

- **Integration Branch**: `main`.
- **Feature Branches**: Use `feature/*`, `bugfix/*`, `chore/*`, or `hotfix/*`.
- **Local Commits**: Create a local branch for all work.
- **Protected Branch**: Commits and pushes to `main` are restricted via git hooks.
- **Merging**: Use PRs merged via GitHub UI.

## Workflow

1. Create a feature branch from `main`.
2. Review existing patterns and list your plan.
3. Obtain explicit approval before editing.
4. Verify your branch.
5. **PR Review**: CodeRabbit reviews the PR automatically on GitHub after `/ship` opens it — no local CLI run (conserves the free-plan review quota). Fetch and address its comments with `/fix-pr`.

## Automation

- **`ci.yml`**: Runs on push/PR to `main`. Executes Terraform `task ci` and Ansible syntax checks.
- **`tailscale.yml`**: Syncs Tailscale ACLs.
- **`renovate.json`**: Managed bot for dependency updates.
