---
name: preflight
description: Run pre-commit quality checks on changed files — ansible-lint, :latest detection, mode field validation, and pre-commit hooks. Fails loudly with a checklist.
user-invocable: true
---

# Preflight Skill

Runs all quality gates on the current branch's changed files and reports a pass/fail checklist. Every check runs even if earlier ones fail — collect all failures, then report.

## Step 1: Get changed files

```bash
git diff --name-only origin/main...HEAD
```

Store the full list. Classify:
- **Ansible files**: any path under `roles/`, `group_vars/`, `host_vars/`, or matching `main.yml`, `bootstrap.yml`
- **Docker Compose files**: any file named `docker-compose*.yml`
- **All YAML**: any `.yml` or `.yaml` file

---

## Check 1 — ansible-lint on changed Ansible files

If there are any Ansible files in the changed list:

```bash
ansible-lint <file1> <file2> ...
```

- Pass: exit 0, zero failures.
- Fail: capture all violations. Each violation is a checklist failure item.

If no Ansible files changed: mark check as **SKIP**.

---

## Check 2 — `:latest` tag in Docker Compose files

If there are any Docker Compose files in the changed list:

```bash
grep -n ':latest' <docker-compose-files>
```

- Pass: no matches.
- Fail: list every matching line as `<file>:<line>: <content>`. Per project policy, all images must be pinned to an explicit version tag.

If no Docker Compose files changed: mark check as **SKIP**.

---

## Check 3 — `copy`/`template` tasks missing `mode:`

For every changed `.yml` file under `roles/`:

```bash
grep -n 'ansible.builtin.copy\|ansible.builtin.template\|  copy:\|  template:' <file>
```

For each match, check whether `mode:` appears within the next 10 lines of that task block. A task is a violation if it uses `copy` or `template` and has no `mode:` key anywhere in its block.

Simpler heuristic — flag any file where the ratio of copy/template occurrences to mode: occurrences is unequal:

```bash
# For each file, count occurrences
grep -c 'ansible\.builtin\.copy\|ansible\.builtin\.template\|\bmodule: copy\|\bmodule: template' <file>
grep -c 'mode:' <file>
```

If copy/template count > mode count, flag the file for manual review with the copy/template line numbers listed.

- Pass: every copy/template task in every changed role file has a `mode:` present.
- Fail: list each file and the line numbers of copy/template tasks that likely lack `mode:`.

If no role YAML files changed: mark check as **SKIP**.

---

## Check 4 — pre-commit hooks

```bash
pre-commit run --all-files 2>&1
```

- Pass: exit 0.
- Fail: capture the full output. Summarize which hooks failed and which files they flagged.

---

## Report: Preflight Checklist

After all checks complete, output exactly this format:

```
## Preflight Results

| Check | Status | Detail |
|-------|--------|--------|
| ansible-lint | ✅ PASS / ❌ FAIL / ⏭ SKIP | <summary or violation count> |
| :latest tags | ✅ PASS / ❌ FAIL / ⏭ SKIP | <summary or file:line list> |
| copy/template mode | ✅ PASS / ❌ FAIL / ⏭ SKIP | <summary or file list> |
| pre-commit | ✅ PASS / ❌ FAIL / ⏭ SKIP | <summary or hook list> |

**Overall: ✅ ALL CHECKS PASSED** or **❌ X CHECK(S) FAILED — do not ship**
```

If any check fails, list the full details under the table so the user knows exactly what to fix.

## Rules

- Never skip a check silently — always show SKIP with a reason.
- Run all 4 checks regardless of earlier failures.
- Do not auto-fix. Report only — the user decides what to fix.
- If `pre-commit` is not installed, mark Check 4 as **SKIP** and note it.
- If `ansible-lint` is not installed, mark Check 1 as **SKIP** and note it.
