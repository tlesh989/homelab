resource "proxmox_lxc" "unifi" {
  target_node  = "huma"
  hostname     = "unifi"
  ostemplate   = "local:vztmpl/ubuntu-22.04-1-_amd64.tar.zst"
  password     = var.root_pass
  unprivileged = true
  onboot       = true

  ssh_public_keys = file("~/.ssh/id_rsa.pub")

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "local-lvm"
    size    = "10G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.233.5/24"
  }
}
