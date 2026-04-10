# Proxmox User

---

## Add a role and create a user with the appropriate permissions

<https://registry.terraform.io/providers/Telmate/proxmox/latest/docs#creating-the-proxmox-user-and-role-for-terraform>

```shell
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.PowerMgmt"
pveum user add terraform-prov@pve --password password
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~>1.14.0 |
| <a name="requirement_doppler"></a> [doppler](#requirement\_doppler) | 1.21.1 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.100.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_doppler"></a> [doppler](#provider\_doppler) | 1.21.1 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_virtual_environment_container.arr](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_container.glance](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_container.netdata](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_container.pi_hole](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_container.plex](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_container.tailscale](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_container.uptime_kuma](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_container) | resource |
| [proxmox_virtual_environment_download_file.ubuntu_24_04_cloud_image](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_download_file) | resource |
| [proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_download_file) | resource |
| [proxmox_virtual_environment_storage_nfs.proxmox_nfs](https://registry.terraform.io/providers/bpg/proxmox/0.100.0/docs/resources/virtual_environment_storage_nfs) | resource |
| [doppler_secrets.this](https://registry.terraform.io/providers/DopplerHQ/doppler/1.21.1/docs/data-sources/secrets) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_default_node_name"></a> [default\_node\_name](#input\_default\_node\_name) | The default Proxmox node to deploy resources on. | `string` | `"bupu"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
