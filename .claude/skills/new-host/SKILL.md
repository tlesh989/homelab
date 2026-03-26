---
name: new-host
description: Bootstrap a new LXC container end-to-end — Terraform provisioning, Ansible bootstrap, then service role deployment
user-invocable: true
disable-model-invocation: true
arguments:
  - name: hostname
    description: "Hostname for the new LXC (kebab-case, e.g. my-service)"
    required: true
---

# New Host Bootstrap

End-to-end workflow for provisioning and configuring a new LXC container in the homelab.

## Step 1 — Gather Info

Ask the user for:

- **Hostname** (kebab-case) — may be provided as `{{hostname}}`
- **Proxmox node** — bupu, sturm, or tika
- **IP address** — must be in the correct subnet for the chosen node
- **VM ID** — check existing `terraform/*.tf` files to avoid conflicts
- **Service role** — which Ansible role to apply after bootstrap (or "none" for bare host)

Do not proceed until all of these are confirmed.

## Step 2 — Scaffold with `/new-service`

Run the `/new-service {{hostname}}` skill to create:

- `terraform/<hostname>.tf`
- `roles/<hostname>/` skeleton
- `hosts` entry under `[<hostname>]`
- `group_vars/<hostname>.yml` stub

## Step 3 — Terraform Apply

```bash
cd terraform && task plan
```

Review the plan with the user. If it looks correct:

```bash
cd terraform && task apply
```

Wait for the LXC to be created. Confirm the container appears in Proxmox.

## Step 4 — Bootstrap Ansible User

```bash
doppler run -- ansible-playbook -b bootstrap.yml --limit <hostname> --tags bootstrap -e "ansible_user=root"
```

- SSH auth uses root on first boot — this creates the `ansible` service account.
- If SSH fails: **stop immediately** and tell the user to check the container is up and SSH is accessible. Do NOT retry in a loop.

## Step 5 — Run Service Role

```bash
task deploy -- <hostname>
```

Or if there's a dedicated task:

```bash
task <hostname>
```

Confirm the deployment passes with no errors.

## Step 6 — Verify Connectivity

```bash
task ping
```

The new host should appear green. If it fails, stop and surface the error to the user.

## Step 7 — Remind User

- Add a `task <hostname>` entry to `Taskfile.yml` if not already present (copy structure from an existing task)
- Ensure the role is included in `main.yml` under the correct host group
- Add any required Doppler secrets for the new service
- Run `task check` to validate the full dry-run

## Rules

- NEVER skip the Terraform plan review — always show the diff to the user before apply
- NEVER retry SSH bootstrap in a loop — SSH failures need human intervention
- NEVER proceed past a failing step without surfacing the error
