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
  }
}

provider "proxmox" {
  endpoint = "https://192.168.233.7:8006/"
  username = var.pm_api_user
  password = var.pm_api_password
  insecure = true
}


