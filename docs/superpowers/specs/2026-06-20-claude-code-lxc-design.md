# Claude Code LXC — Design Spec

**Date:** 2026-06-20
**Status:** Approved

## Goal

Provide a persistent homelab node where Claude Code can be run remotely over SSH (via Tailscale subnet routing), with the Ansible SSH key available on disk (no 1Password unlock required) and GitHub push access via the `gh` CLI.

## LXC Specification

| Field      | Value                        |
|------------|------------------------------|
| Host node  | tika                         |
| Hostname   | `claude-code.tlesh.xyz`      |
| IP         | `192.168.233.25`             |
| OS         | Ubuntu 24.04 LTS             |
| vCPU       | 1                            |
| RAM        | 1 GB                         |
| Disk       | 10 GB                        |
| Type       | Unprivileged LXC             |

Created manually via Proxmox UI, then bootstrapped and managed via Ansible (same pattern as all other LXCs).

## Remote Access

Tailscale subnet routing (via the existing `.21` Tailscale LXC) already advertises `192.168.233.0/24`, so `192.168.233.25` is reachable over Tailscale with no additional configuration. No Tailscale agent needed on this LXC.

## Ansible Role: `roles/claude-code`

New role with a single `tasks/main.yml`. Tasks in order:

1. **Install Node.js 20** — via NodeSource apt repo (same pattern as other roles using external apt repos)
2. **Install Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
3. **Install `gh` CLI** — via GitHub's official apt repo
4. **Install supporting packages** — `git`, `doppler` CLI (for running `doppler run -- ansible-playbook ...`)
5. **Create `tommy` user** — with passwordless sudo (`NOPASSWD: ALL` in sudoers), required for `ansible-playbook` tasks that use `become: true`
6. **Add SSH authorized key** — from `SSH_PUBLIC_KEY` Doppler var (personal ed25519 key, same as other hosts)
7. **Write Ansible SSH key to disk** — `ANSIBLE_SSH_PRIVATE_KEY` from Doppler → `/home/tommy/.ssh/ansible_ed25519`, chmod 600, owned by tommy. No passphrase.
8. **Write SSH config** — adds a `Host *.tlesh.xyz 192.168.233.*` block under `/home/tommy/.ssh/config` pointing `IdentityFile` at `ansible_ed25519` with `IdentitiesOnly yes`
9. **Clone homelab repo** — `https://github.com/tlesh989/homelab` to `/home/tommy/homelab`

## Inventory & Taskfile

- Add `claude-code.tlesh.xyz ansible_host=192.168.233.25` to `hosts` under the `lxc` group
- Add `claude-code` task to `Taskfile.yml` (same pattern as other LXC deploy tasks)

## First-Time Setup (post-deploy, manual, one-time)

After deploying the role, SSH in as `tommy` and run:

```bash
claude auth login     # opens browser URL → paste code back
gh auth login         # opens browser URL → paste code back
doppler login         # opens browser URL → paste code back (for running playbooks)
```

These are interactive OAuth device-flow steps that cannot be automated. All tokens persist on disk after the first login.

## Out of Scope

- Tailscale agent on the LXC (not needed — subnet routing covers it)
- Automatic playbook scheduling (manual SSH + run is the intended workflow)
- Doppler service token automation (device-flow login is sufficient for personal use)
