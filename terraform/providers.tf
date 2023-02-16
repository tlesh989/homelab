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
  }
}

provider "proxmox" {
  pm_api_url    = "https://192.168.233.6:8006/api2/json"
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_debug      = true
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.PowerMgmt"
# pveum user add terraform-prov@pve --password password
# pveum aclmod / -user terraform-prov@pve -role TerraformProv
