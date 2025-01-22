resource "proxmox_lxc" "unifi" {
  provider = proxmox-telmate
  target_node     = "bupu"
  hostname        = "unifi"
  ostemplate      = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  password        = var.ssh_pass
  cores           = 1
  memory          = 2048
  unprivileged    = true
  onboot          = true
  start           = true
  nameserver      = "45.90.28.31 45.90.30.31"
  searchdomain    = "tlesh.xyz"
  tags            = "terraform"
  ssh_public_keys = file("~/.ssh/id_rsa.pub")

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "vm_data"
    size    = "10G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.233.5/24"
    gw     = "192.168.233.1"
  }

  features {
    nesting = true
  }

  mountpoint {
    key     = "0"
    slot    = "0"
    storage = "vm_data"
    mp      = "/mnt/data"
    size    = "10G"
  }
}
