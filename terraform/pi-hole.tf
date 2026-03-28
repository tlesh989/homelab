resource "proxmox_virtual_environment_container" "pi_hole" {
  node_name    = "tika"
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
      operating_system[0].template_file_id,
      initialization[0].user_account,
      disk,
    ]
  }

  tags = ["terraform"]
}

# HA group and resource removed — proxmox_virtual_environment_hagroup is not supported
# in Proxmox VE versions where HA groups have been migrated to rules.
# Configure pi-hole HA manually: Datacenter → HA → Add (ct:102, group: main-group)
