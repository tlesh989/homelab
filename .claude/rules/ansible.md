# Ansible Conventions

## Commands

```bash
task syntax                 # Check playbook syntax
task lint                   # Run ansible-lint
task ping                   # Test connectivity to all hosts
task reqs                   # Install Ansible Galaxy dependencies
task check                  # Dry-run check mode for ALL hosts

# Bootstrap a new LXC (first-time only)
doppler run -- ansible-playbook -b playbooks/bootstrap.yml --limit <hostname> --tags bootstrap -e "ansible_user=root"
```

## Standards

- **Mandatory `name:`**: Every task Must have a descriptive `name:` field.
- **Loops**: Use `loop` instead of `with_items`.
- **Privilege Escalation**: Use `become: true` at the required level, not globally if possible.
- **Permissions**: Any task creating dirs/files for a service user must include `chown -R <puid>:<pgid> <path>` immediately after.
- **Paths**: Use 2-space indentation.
- **Removal is symmetric**: when a task removes or replaces an apt repo, keyring, package, or service, grep the role for every file that setup created (`.list`, `.sources`, `/usr/share/keyrings/*.gpg`, systemd units, etc.) and remove all of them in the same change — not just the one the old task referenced. A stale `.list`/keyring pair left behind by a prior migration (e.g. deb822 or tool-replacement migrations) breaks `apt update` on hosts that were already provisioned. See PR #256.

## Verification (Definition of Done)

- `task syntax` passes.
- `task lint` passes.
- `task check` dry-run shows only expected changes.
- `task ping` confirms connectivity for host-specific changes.
