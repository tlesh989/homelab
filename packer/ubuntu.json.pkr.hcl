variable "root_pass" {
  type      = string
  sensitive = true
}

variable "proxmox_template_name" {
  type    = string
  default = "ubuntu-22.04"
}

variable "proxmox_vm_id" {
  type    = string
  default = "200"
}

variable "ubuntu_iso_file" {
  type    = string
  default = "ubuntu-22.04.1-live-server-amd64.iso"
}

source "proxmox" "ubuntu-server-2204" {
  boot_command = [
    "c",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
    "<enter><wait>",
    "initrd /casper/initrd ",
    "<wait>",
    "initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]
  boot_wait = "5s"
  disks {
    disk_size         = "20G"
    storage_pool      = "local-lvm"
    storage_pool_type = "lvm"
    type              = "virtio"
  }
  http_directory           = "http"
  insecure_skip_tls_verify = "true"
  iso_file                 = "local:iso/${var.ubuntu_iso_file}"
  memory                   = 1024
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }
  node          = "huma"
  proxmox_url   = "https://192.168.233.6:8006/api2/json"
  ssh_password  = "var.root_pass"
  ssh_timeout   = "20m"
  ssh_username  = "root"
  template_name = "${var.proxmox_template_name}"
  unmount_iso   = true
  vm_id         = "${var.proxmox_vm_id}"
}

build {
  sources = ["source.proxmox.ubuntu-server-2204"]

  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo sync"
    ]
  }

}
