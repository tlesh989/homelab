resource "proxmox_lxc" "plex_server" {
  target_node     = "tasslehoff"
  hostname        = "plex"
  ostemplate      = "nfs_proxmox:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  password        = var.ssh_pass
  cores           = 3
  memory          = 12288
  unprivileged    = false
  onboot          = true
  start           = true
  full            = true
  tags            = "terraform"
  ssh_public_keys = file("~/.ssh/id_rsa.pub")

  features {
    mount = "nfs"
  }

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "local-lvm"
    size    = "100G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.233.11/24"
    gw     = "192.168.233.1"
  }
}
