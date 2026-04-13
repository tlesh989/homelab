# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**

```bash
task syntax && task lint  # Fast validation
task check               # Dry-run all hosts
task ping               # Test connectivity
doppler run -- <cmd>    # Inject secrets
```

## Git Workflow (gitnow)

```bash
feature <name>   # Start feature branch
bugfix <name>    # Start bugfix branch
hotfix <name>    # Start hotfix branch
 chore/<name>    # Chore: git checkout -b chore/<name>

# Pre-branch (replaces fetch+checkout+pull):
/clean_gone       # Prune deleted remotes
move main         # Switch to main with autostash
pull              # Rebase pull
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
rm -rf directory     # NOT: rm -r directory
ssh -o BatchMode=yes # Fail instead of prompt
apt-get -y           # Auto-confirm
```

## Landing the Plane

1. File remaining work: `bd create "title" --json`
2. Run quality gates: `task syntax && task lint`
3. Close completed work: `bd close <id> --reason "Done" --json`
4. Push: `git pull --rebase && bd dolt push && git push`
5. Verify push succeeded — resolve conflicts if any.
