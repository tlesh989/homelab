# Proxmox User

---

## Add a role and create a user with the appropriate permissions

<https://github.com/hashicorp/packer/issues/8463#issuecomment-726844945>

```shell
pveum roleadd PackerProv -privs "VM.Config.Disk VM.Config.CPU VM.Config.Memory Datastore.AllocateSpace Datastore.AllocateTemplate Sys.Modify VM.Config.Options VM.Allocate VM.Audit VM.Console VM.Config.CDROM VM.Config.Network VM.PowerMgmt VM.Config.HWType VM.Monitor"
pveum user add packer-prov@pve --password 
pveum aclmod / -user packer-prov@pve -role PackerProv
```