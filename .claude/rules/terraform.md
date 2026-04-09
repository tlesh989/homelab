# Terraform Conventions

## Commands

Run from the root `terraform/` directory:

```bash
task init   # Initialize with Doppler secrets
task plan   # Generate execution plan (requires init)
task apply  # Apply plan (requires task plan first)
task test   # fmt + validate (same as task check)
task ci     # CI check (no Doppler)
```

## Standards

- **Resource Labels**: Use `snake_case` (e.g., `proxmox_nfs`).
- **Infrastructure IDs**: Use `kebab-case` (e.g., `storage_id = "proxmox-nfs"`).
- **Naming Prefixes**: Use standard abbreviations: 
  - `sa-` (Service Account)
  - `sneg-` (Serverless NEG)
  - `lb-` (Load Balancer)
  - `vpc-` (VPC)
  - `db-` (Database)
- **State**: Managed in Terraform Cloud (`tlesh-net` org).
- **Secrets**: Source all secrets from **Doppler**. Never use `.tfvars` or hardcode values.
- **Documentation**: All variables and outputs MUST have `description` fields.
- **Versions**: Use Terraform `>= 1.10`, Google Provider `~> 7.x`. Pin all provider versions in `versions.tf`.

## Verification (Definition of Done)

- `terraform fmt` and `terraform validate` pass (via `task test`).
- `task plan` reviewed before apply.
- CI passes on GitHub after push.
