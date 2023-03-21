resource "proxmox_lxc" "tailscale" {
  target_node     = "huma"
  hostname        = "tailscale"
  ostemplate      = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  password        = var.ssh_pass
  memory          = 2048
  unprivileged    = false
  onboot          = true
  start           = true
  tags            = "terraform"
  ssh_public_keys = file("~/.ssh/id_rsa.pub")

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "local-lvm"
    size    = "10G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }
}
