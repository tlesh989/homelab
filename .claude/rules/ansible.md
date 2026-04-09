# Ansible Conventions

## Commands

```bash
task syntax                 # Check playbook syntax
task lint                   # Run ansible-lint
task ping                   # Test connectivity to all hosts
task reqs                   # Install Ansible Galaxy dependencies
task check                  # Dry-run check mode for ALL hosts

# Bootstrap a new LXC (first-time only)
doppler run -- ansible-playbook -b bootstrap.yml --limit <hostname> --tags bootstrap -e "ansible_user=root"
```

## Standards

- **Mandatory `name:`**: Every task Must have a descriptive `name:` field.
- **Loops**: Use `loop` instead of `with_items`.
- **Privilege Escalation**: Use `become: true` at the required level, not globally if possible.
- **Permissions**: Any task creating dirs/files for a service user must include `chown -R <puid>:<pgid> <path>` immediately after.
- **Paths**: Use 2-space indentation.

## Verification (Definition of Done)

- `task syntax` passes.
- `task lint` passes.
- `task check` dry-run shows only expected changes.
- `task ping` confirms connectivity for host-specific changes.
