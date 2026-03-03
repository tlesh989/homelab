resource "proxmox_virtual_environment_download_file" "ubuntu_22_04_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "bupu"
  url          = "https://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

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
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_22_04_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }
}

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
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_22_04_template.id
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
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_22_04_template.id
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
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_22_04_template.id
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

resource "proxmox_virtual_environment_vm" "ubuntu_cloud" {
  node_name = "bupu"
  vm_id     = 901
}
