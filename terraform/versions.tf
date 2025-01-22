terraform {
  required_version = "~>1.10.0"
  cloud {
    organization = "tlesh-net"

    workspaces {
      name = "homelab"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.69.1"
    }
    linode = {
      source  = "linode/linode"
      version = "1.30.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4"
    }
    nextdns = {
      source  = "amalucelli/nextdns"
      version = "~>0.2"
    }
    unifi = {
      source  = "paultyng/unifi"
      version = "0.41.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.233.7:8006/api2/json"
  insecure = true
  ssh {
    agent    = true
    username = "terraform-prov"
  }
  # log_enable = true
  # log_file   = "terraform-plugin-proxmox.log"
  # debug      = true
  # log_levels = {
  #   _default    = "debug"
  #   _capturelog = ""
  # }
}

provider "cloudflare" {
  api_token = var.cf_tlesh_net_api
}
