resource "proxmox_storage_nfs" "proxmox_nfs" {
  nodes = ["bupu", "sturm", "tika"]
  id    = "proxmox-nfs"

  server = "192.168.220.6"
  export = "/mnt/wayreth/proxmox-nfs"

  content = ["backup", "images", "import", "iso", "rootdir", "snippets", "vztmpl"]

  lifecycle {
    # bpg/proxmox provider bug: `options` flips between null and a computed value
    # on every plan, producing a perpetual diff. Ignored until the provider fixes
    # this. While active, `options` cannot be managed via Terraform.
    ignore_changes = [options]
  }
}

moved {
  from = proxmox_virtual_environment_storage_nfs.proxmox_nfs
  to   = proxmox_storage_nfs.proxmox_nfs
}

resource "proxmox_download_file" "ubuntu_24_04_lxc_template" {
  content_type = "vztmpl"
  datastore_id = proxmox_storage_nfs.proxmox_nfs.id
  node_name    = "bupu"
  url          = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  overwrite    = true
}

moved {
  from = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template
  to   = proxmox_download_file.ubuntu_24_04_lxc_template
}

resource "proxmox_download_file" "ubuntu_24_04_cloud_image" {
  content_type = "iso"
  datastore_id = proxmox_storage_nfs.proxmox_nfs.id
  node_name    = "bupu"
  url          = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
  overwrite    = false
}

moved {
  from = proxmox_virtual_environment_download_file.ubuntu_24_04_cloud_image
  to   = proxmox_download_file.ubuntu_24_04_cloud_image
}
