resource "proxmox_lxc" "tailscale" {
  provider = proxmox-telmate
  target_node     = "bupu"
  hostname        = "tailscale"
  # ostemplate      = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  # password        = var.ssh_pass
  cores           = 1
  memory          = 2048
  unprivileged    = false
  onboot          = true
  start           = true
  tags            = "terraform"
  # ssh_public_keys = file("~/.ssh/id_rsa.pub")

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "vm_data"
    size    = "10G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  nameserver   = "45.90.28.31 45.90.30.31"
  searchdomain = "tlesh.xyz"

  features {
    nesting = true
  }
}
