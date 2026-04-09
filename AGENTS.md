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
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**

- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)
**IMPORTANT**: Use `bd` for ALL tracking. No markdown TODOs. Always use `--json`. 

- **Find work**: `bd ready --json`
- **Claim task**: `bd update <id> --claim --json`
- **Create task**: `bd create "Title" --description="Details" -t bug|feature|task|epic|chore -p 0-4 --json`
- **Subtask/Discovered**: append `--deps discovered-from:<parent-id>`
- **Complete task**: `bd close <id> --reason "Done" --json`

*Priorities: 0 (Crit), 1 (High), 2 (Med), 3 (Low), 4 (Backlog).*

## Landing the Plane (Session Completion)
You MUST complete these before ending a session. Work is NOT done until `git push` succeeds.

1. **File issues**: Any remaining work gets a `bd create`
2. **Quality Gates**: Run linting/tests.
3. **Update Status**: `bd close` finished work.
4. **PUSH (MANDATORY)**: 
   ```bash
   git pull --rebase && bd dolt push && git push
   ```
5. **Verify**: MUST push successfully. Never stop before pushing or say "ready when you are". Resolve conflicts if any.
<!-- END BEADS INTEGRATION -->
