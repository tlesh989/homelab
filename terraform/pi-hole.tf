resource "proxmox_virtual_environment_container" "pi_hole" {
  node_name    = "sturm"
  vm_id        = 102
  unprivileged = true

  features {
    nesting = true
  }

  disk {
    datastore_id = "truenas-lvm"
    size         = 8
  }

  initialization {
    hostname = "pi-hole"

    dns {
      domain  = "tlesh.xyz"
      servers = ["1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.3/24"
        gateway = "192.168.233.1"
      }
    }

    user_account {
      keys = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
      # PM_API_PASSWORD reused for container root password (project-wide convention).
      # initialization[0].user_account is in ignore_changes — only applied at initial creation.
      # TODO: consider using a dedicated PIHOLE_ROOT_PASSWORD secret
      password = data.doppler_secrets.this.map.PM_API_PASSWORD
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
      node_name,
      operating_system[0].template_file_id,
      initialization[0].user_account,
      disk,
    ]
  }

  tags = ["terraform"]
}

resource "proxmox_virtual_environment_hagroup" "main" {
  group   = "main-group"
  comment = "Primary HA group — prefer sturm, failover to bupu/tika"

  nodes = {
    sturm = 3
    bupu  = 2
    tika  = 1
  }
}

resource "proxmox_virtual_environment_haresource" "pi_hole" {
  resource_id  = "ct:102"
  state        = "started"
  max_restart  = 3
  max_relocate = 3
  group        = proxmox_virtual_environment_hagroup.main.group

  depends_on = [proxmox_virtual_environment_container.pi_hole]
}
