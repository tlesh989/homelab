# Glance LXC Design

**Date:** 2026-03-02

## Overview

Provision a Glance dashboard LXC container on Proxmox using Terraform, then configure it with Ansible. Glance is a Go-based personal homepage/dashboard that runs as a systemd service.

## Decisions

- **Node:** bupu (192.168.233.8)
- **VM ID:** 104
- **IP:** 192.168.233.22/24, gateway 192.168.233.1
- **OS:** Ubuntu 22.04 (reuses existing template on bupu)
- **Unprivileged:** true
- **Resources:** 1 CPU core, 512MB RAM, 2GB disk on vm_data
- **Port:** 8080

## Terraform

Add `proxmox_virtual_environment_container.glance` to `terraform/main.tf`:

- Reuses the existing `proxmox_virtual_environment_download_file.ubuntu_22_04_template` resource
- Static IP 192.168.233.22/24
- Tagged `terraform` to match existing containers
- `lifecycle.ignore_changes` on `template_file_id`

## Ansible

### Inventory (`hosts`)

- Add `glance.tlesh.xyz ansible_host=192.168.233.22` in a new `[glance]` group
- Add `glance` to `[lxc:children]` to inherit `ansible_ssh_user=root` and lxc vars

### Playbook (`main.yml`)

New play for `hosts: glance` with roles:

- `grog.package`
- `geerlingguy.ntp`
- `geerlingguy.security`
- `users`
- `glance` (new role)

### Group Vars (`group_vars/glance.yml`)

Glance-specific package/variable overrides as needed.

### Role: `roles/glance`

```text
roles/glance/
  defaults/main.yml       # glance_version, glance_port: 8080, glance_install_dir: /opt/glance
  tasks/main.yml          # download, extract, template config+service, systemd enable/start
  templates/
    glance.yml.j2         # Glance config template (server port, widgets)
    glance.service.j2     # systemd unit
  handlers/main.yml       # restart glance on config change
```

**Tasks flow:**

1. Fetch latest release from GitHub API (or use pinned `glance_version`)
2. Download and extract `glance-linux-amd64.tar.gz` to `/opt/glance/`
3. Template `glance.yml` → `/opt/glance/glance.yml`
4. Template `glance.service` → `/etc/systemd/system/glance.service`
5. `systemd daemon-reload`, enable and start service
