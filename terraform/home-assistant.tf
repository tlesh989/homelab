resource "proxmox_download_file" "haos_image" {
  content_type = "iso"
  datastore_id = proxmox_storage_nfs.proxmox_nfs.id
  node_name    = "bupu"
  url          = "https://github.com/home-assistant/operating-system/releases/download/18.4/haos_ova-18.4.qcow2.xz"
  # Proxmox's zst decompressor handles .xz; .img avoids the file-extension check
  decompression_algorithm = "zst"
  file_name               = "haos_ova-18.4.qcow2.img"
  overwrite               = false
}

resource "proxmox_virtual_environment_vm" "home_assistant" {
  name        = "home-assistant"
  description = "Home Assistant OS — managed by Terraform"
  tags        = ["terraform", "haos"]

  # Pinned to bupu for future USB radio (Zigbee/Z-Wave/Thread) passthrough
  node_name = "bupu"
  vm_id     = 123

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  stop_on_destroy = true

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id      = proxmox_storage_nfs.proxmox_nfs.id
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = proxmox_storage_nfs.proxmox_nfs.id
    file_id      = proxmox_download_file.haos_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 32
  }

  network_device {
    bridge      = "vmbr0"
    firewall    = true
    mac_address = "BC:24:11:12:30:01"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
    ]
  }
}
