terraform {
  required_version = "~>1.14.0"
  cloud {
    organization = "tlesh-net"

    workspaces {
      name = "homelab"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.1"
    }
    # linode = {
    #   source  = "linode/linode"
    #   version = "3.0.0"
    # }
    # cloudflare = {
    #   source  = "cloudflare/cloudflare"
    #   version = "~>5"
    # }
    # nextdns = {
    #   source  = "amalucelli/nextdns"
    #   version = "~>0.2"
    # }
    # unifi = {
    #   source  = "paultyng/unifi"
    #   version = "0.41.0"
    # }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.233.7:8006/"
  username = var.pm_api_user
  password = var.pm_api_password
  insecure = true
}

# provider "cloudflare" {
#   api_token = var.cf_tlesh_net_api
# }
