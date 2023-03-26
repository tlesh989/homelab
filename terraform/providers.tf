terraform {
  cloud {
    organization = "tlesh-net"

    workspaces {
      name = "homelab"
    }
  }

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.13"
    }
    linode = {
      source  = "linode/linode"
      version = "1.30.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.1.0"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://192.168.233.6:8006/api2/json"
  # pm_log_enable = true
  # pm_log_file   = "terraform-plugin-proxmox.log"
  # pm_debug      = true
  # pm_log_levels = {
  #   _default    = "debug"
  #   _capturelog = ""
}

provider "cloudflare" {
  api_token = var.cf_tlesh_net_api
}
