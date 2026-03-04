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

    user_account {
      keys     = [file("~/.ssh/id_ed25519_tlesh.pub")]
      password = data.doppler_secrets.this.map.ROOT_PASSWORD
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
