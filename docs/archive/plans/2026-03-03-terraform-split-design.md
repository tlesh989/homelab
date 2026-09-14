# Terraform main.tf Split — Design

**Date:** 2026-03-03

## Problem

`terraform/main.tf` contains all resource definitions (NFS storage, download files, and 4 LXC
containers) in a single file, making it hard to read and manage as the homelab grows.

There is also a stale Terraform state entry referencing `local-lvm:base-901-disk-0` that causes
`terraform plan` to fail with HTTP 500. This must be resolved before applying changes.

## Design

### Step 1 — Fix stale state (manual)

Identify and remove the orphaned state entry:

```bash
cd terraform
doppler run -- sh -c 'TF_TOKEN_app_terraform_io=$TF_TOKEN terraform state list'
# Find the resource referencing local-lvm:base-901-disk-0
doppler run -- sh -c 'TF_TOKEN_app_terraform_io=$TF_TOKEN terraform state rm <resource_address>'
```

Verify with `task plan` — should succeed and show NFS storage as new resource.

### Step 2 — Apply NFS changes

```bash
task apply
```

### Step 3 — Split main.tf (Option B: storage shared, one file per service)

Delete `main.tf`. Distribute its contents across:

| File | Resources |
|------|-----------|
| `storage.tf` | `proxmox_virtual_environment_storage_nfs.proxmox_nfs`, `proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template`, `proxmox_virtual_environment_download_file.ubuntu_24_04_cloud_image` |
| `pi-hole.tf` | `proxmox_virtual_environment_container.pi_hole` |
| `plex.tf` | `proxmox_virtual_environment_container.plex` |
| `tailscale.tf` | `proxmox_virtual_environment_container.tailscale` |
| `glance.tf` | `proxmox_virtual_environment_container.glance` |

Existing files untouched: `versions.tf`, `doppler.tf`, `variables.tf`, `outputs.tf`.

### Step 4 — Verify no drift

```bash
task plan
```

Plan output must show no resource changes after the split.

## Constraints

- Pure file reorganization — no resource logic changes.
- No new variables, outputs, or modules introduced.
- All resource references (e.g. `proxmox_virtual_environment_storage_nfs.proxmox_nfs.id`) remain
  valid across files since Terraform treats all `.tf` files in a directory as one configuration.
