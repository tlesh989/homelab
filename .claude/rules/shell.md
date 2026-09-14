# Shell Script Conventions

## Strict Mode

Every `.sh` file must start with:

```sh
#!/usr/bin/env bash
set -euo pipefail
```

- No `#!/bin/sh` — scripts use Bash-specific features (`[[`, arrays, `$(())`) and CodeRabbit enforces the Bash shebang.
- `pipefail` matters for piped commands (`cmd | awk ...`) — without it a failing `cmd` is masked by a successful `awk`.
- Bound any command that can hang (network calls, storage probes) with `timeout`, since `set -e` won't rescue a stuck process.
- A best-effort script that gives up after retries must still `exit` non-zero if the condition it was gating on was never met — a silent `exit 0` defeats the caller's gate (e.g. a systemd `ExecStartPre`).

Enforced automatically by CodeRabbit (`.coderabbit.yaml` → `path_instructions` for `**/*.sh`).
