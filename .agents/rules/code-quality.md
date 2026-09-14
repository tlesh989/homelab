# Code Quality & Behavior

Behavioral guidelines to reduce common mistakes. These apply to all infra changes (Ansible, Terraform, Docker).

## Think Before Coding

**Don't assume. Surface tradeoffs. Ask when uncertain.**

Before implementing:
- State assumptions explicitly — especially host IPs, service names, port assignments, or Doppler variable names.
- If multiple interpretations exist, present them. Don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

> Infra assumptions that turn out wrong break live services. Clarify first.

## Simplicity First

**Minimum change that solves the problem. Nothing speculative.**

- No role variables, tasks, or handlers beyond what was asked.
- No "future-proof" abstractions for a single-use pattern.
- No error handling for scenarios that can't happen in this homelab.
- If a task can be done in one handler, don't make it three.

Ask: "Would this confuse someone reading it in 6 months?" If yes, simplify.

## Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing playbooks, roles, or configs:
- Don't "improve" adjacent tasks, comments, or formatting that aren't broken.
- Don't refactor things outside the scope of the request.
- Match existing style, indentation, and naming — even if you'd do it differently.
- If you notice unrelated dead code or stale config, mention it — don't delete it.

When your changes create orphans:
- Remove variables/defaults/handlers that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

## Goal-Driven Execution

**For multi-step tasks, state a brief plan and verify each step.**

Format:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Example:
```
1. Add `truenas_verify_tls` default → verify: task lint passes
2. Wire env var into docker-compose template → verify: task syntax passes
3. Deploy to kaz → verify: exporter scrapes without SSL error
```

Weak success criteria ("make it work") lead to rework. Define what done looks like before starting.
