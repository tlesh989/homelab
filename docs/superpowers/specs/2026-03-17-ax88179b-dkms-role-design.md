# Design: `roles/ax88179b` — ASIX AX88179B DKMS Driver

**Date:** 2026-03-17
**Status:** Approved

## Context

tika (Proxmox node at 192.168.233.7) has an ASIX AX88179B USB NIC (USB ID `0b95:1790`). The in-tree
`ax88179_178a` kernel driver does **not** support the B revision — the device shows `Driver=[none]` in
`lsusb -t`. The official ASIX out-of-tree driver tarball supports it and must be built via DKMS.

bupu has a confirmed working AX88179 (non-B) on the in-tree driver. This role must only run on tika.

## Goals

- Install the ASIX out-of-tree driver (`ax_usb_nic` module) via DKMS on tika
- Survive kernel upgrades by building for all installed PVE kernels
- Ensure `ax_usb_nic` wins the device binding race against `cdc_ncm`
- Be opt-in (off by default) so it never touches bupu or sturm

## Non-Goals

- System-wide blacklisting of `cdc_ncm` (breaks USB tethering and other CDC devices)
- Automated ASIX version bumping (pin to 3.5.0)

## File Structure

```
roles/ax88179b/
  defaults/main.yml
  tasks/main.yml
  handlers/main.yml
  templates/dkms.conf.j2
group_vars/tika.yml          # new file — enables the role on tika
```

## Key Facts

| Variable | Value |
|---|---|
| `ax88179b_dkms_name` | `asix-ax88179` |
| `ax88179b_driver_version` | `3.5.0` |
| `ax88179b_module_name` | `ax_usb_nic` (ASIX out-of-tree module name, **not** `ax88179_178a`) |
| `ax88179b_usb_vendor` | `0b95` |
| `ax88179b_usb_product` | `1790` |
| Download URL | `https://www.asix.com.tw/en/support/download/file/2089?time=1773781972531` |

## `defaults/main.yml`

```yaml
---
# defaults file for ax88179b

ax88179b_enabled: false  # opt-in; set true in group_vars/tika.yml
ax88179b_driver_version: "3.5.0"
ax88179b_download_url: "https://www.asix.com.tw/en/support/download/file/2089?time=1773781972531"
ax88179b_dkms_name: "asix-ax88179"
ax88179b_module_name: "ax_usb_nic"
ax88179b_usb_vendor: "0b95"
ax88179b_usb_product: "1790"
```

## `templates/dkms.conf.j2`

The ASIX tarball ships a `Makefile` but no `dkms.conf`. The role templates one in before `dkms add`.

```ini
PACKAGE_NAME="{{ ax88179b_dkms_name }}"
PACKAGE_VERSION="{{ ax88179b_driver_version }}"
BUILT_MODULE_NAME[0]="{{ ax88179b_module_name }}"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/usb/"
AUTOINSTALL="yes"
MAKE[0]="make"
CLEAN="make clean"
```

## `tasks/main.yml` — Logic Flow

All tasks are gated behind `when: ax88179b_enabled | bool` at the play level (via `main.yml` role entry).

### 1. Install Proxmox kernel headers for all installed kernels

Mirror the `r8152` pattern: enumerate all installed PVE kernels via `dpkg -l 'pve-kernel-[0-9]*'`,
then install `proxmox-headers-<ver>` for each. Use `failed_when: false` — headers for old kernels
that have been removed from the repo will be skipped gracefully.

### 2. Install build toolchain

```yaml
apt:
  name: [dkms, build-essential]
```

### 3. Check if DKMS module already installed

```bash
set -o pipefail && dkms status | grep -q "{{ ax88179b_dkms_name }}/{{ ax88179b_driver_version }}"
```

Register result as `ax88179b_dkms_check`. Steps 4–7 are skipped when `rc == 0`.

### 4. Download tarball

`ansible.builtin.get_url` → `/tmp/asix-ax88179b.tar.bz2`

### 5. Extract source

`ansible.builtin.unarchive` (with `remote_src: true`) →
`/usr/src/{{ ax88179b_dkms_name }}-{{ ax88179b_driver_version }}/`

The ASIX 3.5.0 tarball extracts into a top-level subdirectory (e.g. `ASIX_USB_NIC_Linux_Driver_v3.5.0/`).
Use `extra_opts: ['--strip-components=1']` to flatten into the target path, or inspect the tarball
on first run and pin the exact directory name here before merging.

### 6. Template `dkms.conf`

`ansible.builtin.template` → `/usr/src/{{ ax88179b_dkms_name }}-{{ ax88179b_driver_version }}/dkms.conf`

### 7. DKMS add/build/install (multi-kernel)

Shell block matching `r8152` pattern: iterate all `/lib/modules/<kver>` entries that have a `build/`
symlink, skip versions already installed, fail hard if the running kernel's build fails.

`dkms add` is idempotent-guarded: check `dkms status` first and only add if not already registered.
The build loop emits `installed=N` so `changed_when` can detect real work vs. no-op re-runs.

```bash
set -o pipefail
dkms status "{{ ax88179b_dkms_name }}/{{ ax88179b_driver_version }}" 2>/dev/null | grep -q . \
  || dkms add -m {{ ax88179b_dkms_name }} -v {{ ax88179b_driver_version }}
RUNNING_KVER=$(uname -r)
INSTALLED=0
for kver in $(ls /lib/modules); do
  [ -d "/lib/modules/$kver/build" ] || continue
  dkms status "{{ ax88179b_dkms_name }}/{{ ax88179b_driver_version }}" -k "$kver" \
    2>/dev/null | grep -q installed && continue
  dkms build "{{ ax88179b_dkms_name }}/{{ ax88179b_driver_version }}" -k "$kver" 2>/dev/null \
    || { [ "$kver" = "$RUNNING_KVER" ] && exit 1; true; }
  dkms install "{{ ax88179b_dkms_name }}/{{ ax88179b_driver_version }}" -k "$kver" 2>/dev/null \
    || { [ "$kver" = "$RUNNING_KVER" ] && exit 1; true; }
  INSTALLED=$((INSTALLED + 1))
done
echo "installed=$INSTALLED"
```

`changed_when: "'installed=0' not in _ax88179b_dkms_build.stdout"` (mirrors r8152 pattern).
Entire block: `when: ax88179b_dkms_check.rc != 0`

### 8. Add `ax_usb_nic` to `/etc/modules`

`ansible.builtin.lineinfile` — idempotent, adds `ax_usb_nic` if not present. This loads the module
early at boot, winning the device binding race against `cdc_ncm`.

### 9. Udev fallback rule

Write `/etc/udev/rules.d/50-ax88179b.rules` via `ansible.builtin.copy`. The `copy` task notifies
the `Reload udev rules` handler — udev is only reloaded when the rules file actually changes.

```
# Unbind cdc_ncm if it claims the AX88179B before ax_usb_nic, then bind ax_usb_nic.
# Primary fix is /etc/modules loading ax_usb_nic early; this rule is a fallback.
ACTION=="bind", SUBSYSTEM=="usb", ATTR{idVendor}=="0b95", ATTR{idProduct}=="1790", DRIVER=="cdc_ncm", RUN+="/bin/sh -c 'echo $kernel > /sys/bus/usb/drivers/cdc_ncm/unbind; echo $kernel > /sys/bus/usb/drivers/ax_usb_nic/bind'"
```

Design rationale: device-specific (does not affect other CDC devices), no initramfs rebuild needed,
survives kernel upgrades. Do NOT blacklist `cdc_ncm` system-wide — it would break USB tethering and
other CDC-class devices.

### 10. Notify handler — load module for current boot

Notifies the `Load ax_usb_nic module` handler (e.g. after DKMS install or first run).

## `handlers/main.yml`

Two handlers — udev reload is triggered by the rules file `copy` task; modprobe is triggered after
DKMS install to activate the module for the current boot without rebooting.

```yaml
- name: Reload udev rules
  ansible.builtin.shell:
    cmd: udevadm control --reload-rules && udevadm trigger
    executable: /bin/bash
  changed_when: true

- name: Load ax_usb_nic module
  community.general.modprobe:
    name: ax_usb_nic
    state: present
```

## Integration Changes

### `group_vars/tika.yml` (new file)

```yaml
---
# tika-specific overrides
ax88179b_enabled: true
```

### `main.yml` — `setup proxmox hosts` play

Add after `install_script`, before `r8152`:

```yaml
- role: ax88179b
  when: ax88179b_enabled | default(false)
```

## Validation

After implementation:

```bash
task syntax   # playbook syntax check
task lint     # ansible-lint
```

Do NOT run `task proxmox` — no deployment, just lint clean.

## Design Decisions

| Decision | Rationale |
|---|---|
| Module name is `ax_usb_nic` not `ax88179_178a` | ASIX out-of-tree driver exports `ax_usb_nic`; the in-tree driver uses `ax88179_178a` |
| `proxmox-headers-*` not `linux-headers-*` | Proxmox ships its own kernel headers; `linux-headers` will not be found on PVE hosts |
| Build for all kernels, not just running | Mirrors `r8152` pattern; prevents breakage after `pve-manager` upgrades the kernel |
| Template `dkms.conf` | ASIX tarball includes only a `Makefile`; DKMS requires `dkms.conf` to register the module |
| Udev unbind/bind over blacklist | `cdc_ncm` is a generic CDC class driver; blacklisting it system-wide would break USB tethering and other adapters |
| `/etc/modules` early load | `ax_usb_nic` wins the binding race without needing the udev fallback in the common case |
