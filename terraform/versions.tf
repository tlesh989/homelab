terraform {
  required_version = "~>1.14.0"
  cloud {
    organization = "tlesh-net"

    workspaces {
      name = "homelab"
    }
  }

  required_providers {
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "1.21.1"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.1"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.233.7:8006/"
  username = nonsensitive(data.doppler_secrets.this.map.PM_API_USER)
  password = nonsensitive(data.doppler_secrets.this.map.PM_API_PASSWORD)
  insecure = true
}


