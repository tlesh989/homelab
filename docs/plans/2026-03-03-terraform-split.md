# Terraform main.tf Split Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix stale Terraform state blocking `task plan`, apply NFS storage changes, then split `main.tf` into one file per service.

**Architecture:** Pure file reorganization — no logic changes. Terraform treats all `.tf` files in a directory as one configuration, so moving resources between files has zero runtime impact. The stale state fix is a manual prerequisite that must be done before any apply.

**Tech Stack:** Terraform ~1.14, bpg/proxmox provider 0.97.1, Terraform Cloud (state backend), Doppler (secrets)

---

## Prerequisites (manual — cannot be automated)

These steps require interactive terminal access and must be completed before Task 1.

### Pre-1: Identify the stale state entry

```bash
cd terraform
doppler run -- sh -c 'TF_TOKEN_app_terraform_io=$TF_TOKEN terraform state list'
```

Look for a resource whose ID contains `local-lvm:base-901-disk-0`. It will be something like:

- `proxmox_virtual_environment_download_file.ubuntu_24_04_cloud_image`
- `proxmox_virtual_environment_vm.some_template`

### Pre-2: Remove the stale state entry

```bash
doppler run -- sh -c 'TF_TOKEN_app_terraform_io=$TF_TOKEN terraform state rm <resource_address>'
```

Expected output: `Removed <resource_address>`

### Pre-3: Verify plan now succeeds

```bash
task plan
```

Expected: Plan runs without HTTP 500 error. Should show `proxmox_virtual_environment_storage_nfs.proxmox_nfs` as a resource to create (the NFS storage we added).

### Pre-4: Apply NFS changes

```bash
task apply
```

Expected: NFS storage resource created successfully.

---

## Task 1: Create storage.tf

**Files:**

- Create: `terraform/storage.tf`
- Modify: `terraform/main.tf` (remove the 3 resources being moved)

### Step 1: Create storage.tf with NFS + download\_file resources

Exact content:

```hcl
resource "proxmox_virtual_environment_storage_nfs" "proxmox_nfs" {
  nodes = ["bupu"]
  id    = "proxmox-nfs"

  server = "192.168.233.6"
  export = "/volume1/proxmox_nfs"

  content = ["backup", "images", "import", "iso", "rootdir", "snippets", "vztmpl"]
  # shared  = true
}

resource "proxmox_virtual_environment_download_file" "ubuntu_24_04_lxc_template" {
  content_type = "vztmpl"
  datastore_id = proxmox_virtual_environment_storage_nfs.proxmox_nfs.id
  node_name    = "bupu"
  url          = "https://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  overwrite    = true
}

resource "proxmox_virtual_environment_download_file" "ubuntu_24_04_cloud_image" {
  content_type = "iso"
  datastore_id = proxmox_virtual_environment_storage_nfs.proxmox_nfs.id
  node_name    = "bupu"
  url          = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  overwrite    = true
}
```

### Step 2: Remove those 3 resources from main.tf

Delete lines 1–26 from `terraform/main.tf` (the `proxmox_virtual_environment_storage_nfs` block and both `proxmox_virtual_environment_download_file` blocks).

### Step 3: Verify plan shows no changes

```bash
task plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

### Step 4: Commit

```bash
git add terraform/storage.tf terraform/main.tf
git commit -m "refactor: extract storage and templates to storage.tf"
```

---

## Task 2: Create pi-hole.tf

**Files:**

- Create: `terraform/pi-hole.tf`
- Modify: `terraform/main.tf` (remove pi-hole resource)

### Step 1: Create pi-hole.tf

```hcl
resource "proxmox_virtual_environment_container" "pi_hole" {
  node_name    = "sturm"
  vm_id        = 102
  unprivileged = true

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  disk {
    datastore_id = "vm_data"
    size         = 8
  }

  initialization {
    hostname = "pi-hole"

    dns {
      domain = "127.0.0.1"
      servers = [
        "1.1.1.1",
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.3/24"
        gateway = "192.168.233.1"
      }
    }
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:F4:5D:EC"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }
}
```

### Step 2: Remove the pi\_hole resource from main.tf

Delete the `proxmox_virtual_environment_container.pi_hole` block (lines 28–85 in the original file — adjust for current line numbers after Task 1).

### Step 3: Verify plan shows no changes

```bash
task plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

### Step 4: Commit

```bash
git add terraform/pi-hole.tf terraform/main.tf
git commit -m "refactor: extract pi-hole container to pi-hole.tf"
```

---

## Task 3: Create plex.tf

**Files:**

- Create: `terraform/plex.tf`
- Modify: `terraform/main.tf` (remove plex resource)

### Step 1: Create plex.tf

```hcl
resource "proxmox_virtual_environment_container" "plex" {
  node_name    = "bupu"
  vm_id        = 103
  unprivileged = false

  cpu {
    architecture = "amd64"
    cores        = 3
    units        = 1024
  }

  disk {
    datastore_id = "vm_data"
    size         = 100
  }

  initialization {
    hostname = "plex"

    ip_config {
      ipv4 {
        address = "192.168.233.12/24"
        gateway = "192.168.233.1"
      }
    }
  }

  memory {
    dedicated = 12288
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = false
    mac_address = "BC:24:11:74:AB:1A"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }

  tags = [
    "terraform",
  ]
}
```

### Step 2: Remove the plex resource from main.tf

Delete the `proxmox_virtual_environment_container.plex` block.

### Step 3: Verify plan shows no changes

```bash
task plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

### Step 4: Commit

```bash
git add terraform/plex.tf terraform/main.tf
git commit -m "refactor: extract plex container to plex.tf"
```

---

## Task 4: Create tailscale.tf

**Files:**

- Create: `terraform/tailscale.tf`
- Modify: `terraform/main.tf` (remove tailscale resource)

### Step 1: Create tailscale.tf

```hcl
resource "proxmox_virtual_environment_container" "tailscale" {
  node_name    = "tika"
  vm_id        = 101
  unprivileged = false

  disk {
    datastore_id = "vm_data"
    size         = 10
  }

  initialization {
    hostname = "tailscale"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  memory {
    dedicated = 2048
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = false
    mac_address = "EA:31:E7:19:05:63"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }

  tags = [
    "terraform",
  ]
}
```

### Step 2: Remove the tailscale resource from main.tf

Delete the `proxmox_virtual_environment_container.tailscale` block.

### Step 3: Verify plan shows no changes

```bash
task plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

### Step 4: Commit

```bash
git add terraform/tailscale.tf terraform/main.tf
git commit -m "refactor: extract tailscale container to tailscale.tf"
```

---

## Task 5: Create glance.tf and delete main.tf

**Files:**

- Create: `terraform/glance.tf`
- Delete: `terraform/main.tf`

### Step 1: Create glance.tf

```hcl
resource "proxmox_virtual_environment_container" "glance" {
  node_name    = "bupu"
  vm_id        = 104
  unprivileged = true

  disk {
    datastore_id = "vm_data"
    size         = 8
  }

  initialization {
    hostname = "glance"

    ip_config {
      ipv4 {
        address = "192.168.233.22/24"
        gateway = "192.168.233.1"
      }
    }
  }

  memory {
    dedicated = 512
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:A2:3C:44"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }

  tags = [
    "terraform",
  ]
}
```

### Step 2: Verify main.tf is now empty (or delete it)

After removing all resources, `main.tf` should be empty. Delete it:

```bash
rm terraform/main.tf
```

### Step 3: Verify plan shows no changes

```bash
task plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

### Step 4: Commit

```bash
git add terraform/glance.tf terraform/main.tf
git commit -m "refactor: extract glance container to glance.tf, remove main.tf"
```

---

## Final Verification

```bash
task plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

Final directory should contain:

```text
terraform/
├── disabled/
├── doppler.tf
├── glance.tf
├── outputs.tf
├── pi-hole.tf
├── plex.tf
├── storage.tf
├── tailscale.tf
├── Taskfile.yml
├── variables.tf
└── versions.tf
```
