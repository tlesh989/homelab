resource "proxmox_vm_qemu" "preprovision-test" {
  target_node = "huma"
  os_type     = "ubuntu"
  iso         = "ubuntu-22.04.1-live-server-amd64.iso"

  ssh_forward_ip    = "10.0.0.1"
  ssh_user          = "terraform"
  ssh_private_key   = file("~/.ssh/id_rsa.pub")
  os_network_config = <<EOF
auto eth0
iface eth0 inet dhcp
EOF

  connection {
    type        = "ssh"
    user        = self.ssh_user
    private_key = self.ssh_private_key
    host        = self.ssh_host
    port        = self.ssh_port
  }
}
