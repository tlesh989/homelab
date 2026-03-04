resource "proxmox_virtual_environment_storage_nfs" "proxmox_nfs" {
  nodes = ["bupu"]
  id    = "proxmox-nfs"

  server = "192.168.233.6"
  export = "/volume1/proxmox_nfs"

  content = ["backup", "images", "import", "iso", "rootdir", "snippets", "vztmpl"]
  # shared  = true
}

resource "proxmox_virtual_environment_download_file" "ubuntu_24_04_lxc_template" {
  content_type = "vztmpl"
  datastore_id = proxmox_virtual_environment_storage_nfs.proxmox_nfs.id
  node_name    = "bupu"
  url          = "https://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  overwrite    = true
}

resource "proxmox_virtual_environment_download_file" "ubuntu_24_04_cloud_image" {
  content_type = "iso"
  datastore_id = proxmox_virtual_environment_storage_nfs.proxmox_nfs.id
  node_name    = "bupu"
  url          = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  overwrite    = true
}
