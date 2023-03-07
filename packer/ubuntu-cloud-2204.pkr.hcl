variable "ssh_user_name" {
  type = string
}
variable "ssh_user_pass" {
  type      = string
  sensitive = true
}

source "proxmox-clone" "ubuntu-cloud-2204" {
  insecure_skip_tls_verify = true
  full_clone               = true

  template_name = "ubuntu-cloud-2204"
  clone_vm      = "ubuntu-cloud"

  os              = "l26"
  cores           = "1"
  memory          = "2048"
  scsi_controller = "virtio-scsi-single"

  ssh_username = "ubuntu"
  qemu_agent   = true

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  node        = "huma"
  username    = "${var.ssh_user_name}"
  password    = "${var.ssh_user_pass}"
  proxmox_url = "https://192.168.233.6:8006/api2/json"
}

build {
  sources = ["source.proxmox-clone.ubuntu-cloud-2204"]

  provisioner "shell" {
    inline = ["sudo cloud-init clean"]
  }
}
