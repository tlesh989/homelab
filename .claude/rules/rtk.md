# RTK Instructions (Rust Token Killer)

RTK filters command output for token efficiency.

## Golden Rule

**Always prefix commands with `rtk`** — even inside `&&` chains. If RTK has a
dedicated filter it uses it; otherwise it passes the command through unchanged,
so `rtk` is always safe.

```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push
# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

RTK has dedicated filters for build, test, git, gh, package managers, file
search, docker/kubectl, and network commands (60–99% output reduction).

## Full command reference

For the per-command list and savings table, read on demand:
[`.claude/references/rtk-commands.md`](../references/rtk-commands.md)
