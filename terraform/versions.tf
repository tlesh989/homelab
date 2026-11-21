terraform {
  required_version = "~> 1.17.0"
  cloud {
    organization = "tlesh-net"

    workspaces {
      name = "homelab"
    }
  }

  required_providers {
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "1.23.0"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = "0.121.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.233.9:8006/"
  username = nonsensitive(data.doppler_secrets.this.map.PM_API_USER)
  password = data.doppler_secrets.this.map.PM_API_PASSWORD
  insecure = true

  # Needed for SSH-backed operations (e.g. creating a VM disk from a downloaded image).
  # Reuses the Ansible service account, which has NOPASSWD sudo on every node.
  ssh {
    username    = "ansible"
    private_key = data.doppler_secrets.this.map.ANSIBLE_SSH_PRIVATE_KEY
  }
}


