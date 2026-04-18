# Docker Conventions

## Image Tags

- **Never use `:latest`** — pin to a major version tag (e.g., `:2`, `:1`).
- Watchtower handles minor/patch updates within the pinned major line automatically.
- Pin Watchtower itself to a specific version (e.g., `1.14.4`), not a major tag.

## Watchtower

- Use the active fork: `ghcr.io/nicholas-fedor/watchtower` (not `containrrr/watchtower`).
- Deploy one Watchtower per Docker host — do not add it to every stack.
- Watchtower image tag must be a full version (e.g., `1.14.4`), stored in role defaults.

## Environment Variables

- Always pipe values through `| string` in Jinja2 to avoid type coercion errors:
  ```yaml
  env:
    PORT: "{{ service_port | string }}"
  ```

## New Service Checklist

Every new service with a web UI requires all three:

1. **Watchtower** — container auto-update coverage (verify it's on same Docker host)
2. **Uptime Kuma** — add a monitor for the service URL
3. **Glance** — add an entry to the dashboard

## Privilege Escalation

- Tasks using `community.docker.*` modules require `become: true`.
- Install the Docker Python SDK (`python3-docker`) before any `community.docker` task.
- Use `ansible.builtin.package` (not `apt`) for cross-distribution compatibility.
