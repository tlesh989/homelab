# Ubuntu Server 22.04
variable "ssh_user_name" {
  type = string
}
variable "ssh_user_pass" {
  type      = string
  sensitive = true
}

source "proxmox" "ubuntu-server-2204" {

  proxmox_url              = "https://192.168.233.6:8006/api2/json"
  insecure_skip_tls_verify = true

  node                 = "huma"
  vm_id                = "900"
  vm_name              = "ubuntu-server-2204"
  template_description = "Ubuntu Server 22.04"
  iso_file             = "local:iso/ubuntu-22.04.1-live-server-amd64.iso"
  unmount_iso          = true

  qemu_agent = true

  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size         = "20G"
    storage_pool      = "local-lvm"
    storage_pool_type = "lvm"
    type              = "virtio"
    io_thread         = true
  }

  cores  = "1"
  memory = "2048"

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  boot_wait      = "5s"
  http_directory = "http"
  boot_command = [
    "c",
    "<wait>",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<enter><wait>",
    "initrd /casper/",
    "<wait>",
    "initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

  ssh_username = var.ssh_user_name
  ssh_password = var.ssh_user_pass
  ssh_timeout  = "20m"
}

build {

  name    = "ubuntu-server-2204"
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