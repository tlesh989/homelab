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
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~>1.10.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~>4 |
| <a name="requirement_linode"></a> [linode](#requirement\_linode) | 1.30.0 |
| <a name="requirement_nextdns"></a> [nextdns](#requirement\_nextdns) | ~>0.2 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.69.1 |
| <a name="requirement_unifi"></a> [unifi](#requirement\_unifi) | 0.41.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 3.0.1-rc1 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_vm.k8s_master](https://registry.terraform.io/providers/bpg/proxmox/0.69.1/docs/resources/virtual_environment_vm) | resource |
| [random_password.ubuntu_vm_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [tls_private_key.ubuntu_vm_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [proxmox_virtual_environment_datastores.available_datastores](https://registry.terraform.io/providers/bpg/proxmox/0.69.1/docs/data-sources/virtual_environment_datastores) | data source |
| [proxmox_virtual_environment_hosts.first_node_host_entries](https://registry.terraform.io/providers/bpg/proxmox/0.69.1/docs/data-sources/virtual_environment_hosts) | data source |
| [proxmox_virtual_environment_nodes.available_nodes](https://registry.terraform.io/providers/bpg/proxmox/0.69.1/docs/data-sources/virtual_environment_nodes) | data source |
| [proxmox_virtual_environment_pools.available_pools](https://registry.terraform.io/providers/bpg/proxmox/0.69.1/docs/data-sources/virtual_environment_pools) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cf_tlesh_net_api"></a> [cf\_tlesh\_net\_api](#input\_cf\_tlesh\_net\_api) | The Cloudflare API Token for operations. | `string` | n/a | yes |
| <a name="input_cf_tlesh_net_zone"></a> [cf\_tlesh\_net\_zone](#input\_cf\_tlesh\_net\_zone) | The Cloudflare zone identifier to target for the resource. | `string` | n/a | yes |
| <a name="input_default_node_name"></a> [default\_node\_name](#input\_default\_node\_name) | The default Proxmox node to deploy resources on. | `string` | `"bupu"` | no |
| <a name="input_ssh_pass"></a> [ssh\_pass](#input\_ssh\_pass) | Override the default cloud-init user's password. Sensitive. | `string` | n/a | yes |
| <a name="input_ssh_user"></a> [ssh\_user](#input\_ssh\_user) | Only applies when define\_connection\_info is true. The user with which to connect to the guest for preprovisioning. Forces re-creation on change. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_available_datastores"></a> [available\_datastores](#output\_available\_datastores) | n/a |
| <a name="output_available_nodes"></a> [available\_nodes](#output\_available\_nodes) | n/a |
| <a name="output_available_pools"></a> [available\_pools](#output\_available\_pools) | n/a |
| <a name="output_first_node_host_entries"></a> [first\_node\_host\_entries](#output\_first\_node\_host\_entries) | n/a |
| <a name="output_ubuntu_vm_password"></a> [ubuntu\_vm\_password](#output\_ubuntu\_vm\_password) | n/a |
| <a name="output_ubuntu_vm_private_key"></a> [ubuntu\_vm\_private\_key](#output\_ubuntu\_vm\_private\_key) | n/a |
| <a name="output_ubuntu_vm_public_key"></a> [ubuntu\_vm\_public\_key](#output\_ubuntu\_vm\_public\_key) | n/a |
<!-- END_TF_DOCS -->
