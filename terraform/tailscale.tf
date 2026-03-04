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

    user_account {
      keys     = [file("~/.ssh/id_ed25519_tlesh.pub")]
      password = data.doppler_secrets.this.map.ROOT_PASSWORD
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
