# Barlo Remote Site Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provision barlo (Zimablade, Ubuntu 26.04) with minimal GNOME desktop, RDP access, Google Chrome, Tailscale, and Uptime Kuma for bakery network monitoring.

**Architecture:** New `roles/desktop` role encapsulates GNOME + xrdp + Chrome. Existing `roles/uptime_kuma` and `roles/node_exporter` are reused unchanged. A new barlo play in `main.yml` follows the same structure as every other host play (ansible_user → packages → users → ntp → security → tailscale → host-specific roles).

**Tech Stack:** Ansible, artis3n.tailscale.machine, geerlingguy.ntp, geerlingguy.security, ubuntu-desktop-minimal, xrdp, google-chrome-stable, Uptime Kuma (Docker), Prometheus node_exporter

---

## File Map

| Action | Path | Purpose |
|---|---|---|
| Modify | `./hosts` | Add `[barlo]` group; add to `[exporters:children]` |
| Create | `group_vars/barlo.yml` | Host-specific vars (uptime_kuma_timezone) |
| Create | `roles/desktop/defaults/main.yml` | Role defaults (xrdp port, gnome packages) |
| Create | `roles/desktop/tasks/main.yml` | Imports gnome, xrdp, chrome sub-tasks |
| Create | `roles/desktop/tasks/gnome.yml` | Install ubuntu-desktop-minimal, set GDM |
| Create | `roles/desktop/tasks/xrdp.yml` | Install xrdp, configure session, polkit rule |
| Create | `roles/desktop/tasks/chrome.yml` | Add Google apt repo, install chrome-stable |
| Create | `roles/desktop/handlers/main.yml` | Restart xrdp handler |
| Create | `roles/desktop/templates/startwm.sh.j2` | xrdp GNOME session launch script |
| Create | `roles/desktop/files/45-allow-colord.rules` | Polkit rule for colord (suppresses popup) |
| Modify | `main.yml` | Add barlo play after minecraft play |
| Modify | `Taskfile.yml` | Add `barlo` task |

---

## Task 1: Inventory & Host Variables

**Files:**
- Modify: `./hosts`
- Create: `group_vars/barlo.yml`

- [ ] **Step 1: Add barlo to inventory**

In `./hosts`, add the `[barlo]` group after `[minecraft]`:

```ini
[barlo]
barlo.tlesh.xyz ansible_host=192.168.233.126
```

Then add `barlo` to the `[exporters:children]` block:

```ini
[exporters:children]
proxmox
tailscale
plex
pi-hole
arr
uptime-kuma
caddy
minecraft
kaz
barlo
```

- [ ] **Step 2: Create group_vars/barlo.yml**

```yaml
uptime_kuma_timezone: America/Detroit
```

- [ ] **Step 3: Verify syntax**

```bash
task syntax
```

Expected: no errors (barlo group exists, valid YAML)

- [ ] **Step 4: Commit**

```bash
git add hosts group_vars/barlo.yml
git commit -m "feat(barlo): add barlo to inventory and group_vars"
```

---

## Task 2: Desktop Role — Scaffold & Defaults

**Files:**
- Create: `roles/desktop/defaults/main.yml`
- Create: `roles/desktop/tasks/main.yml`

- [ ] **Step 1: Create role directory structure**

```bash
mkdir -p roles/desktop/defaults roles/desktop/tasks roles/desktop/handlers roles/desktop/templates roles/desktop/files
```

- [ ] **Step 2: Create roles/desktop/defaults/main.yml**

```yaml
desktop_xrdp_port: 3389
desktop_gnome_packages:
  - ubuntu-desktop-minimal
```

- [ ] **Step 3: Create roles/desktop/tasks/main.yml**

```yaml
- name: Install GNOME desktop
  ansible.builtin.import_tasks: gnome.yml

- name: Configure xrdp remote desktop
  ansible.builtin.import_tasks: xrdp.yml

- name: Install Google Chrome
  ansible.builtin.import_tasks: chrome.yml
```

- [ ] **Step 4: Verify syntax**

```bash
task syntax
```

Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add roles/desktop/
git commit -m "feat(desktop): scaffold desktop role with defaults and task imports"
```

---

## Task 3: Desktop Role — GNOME Install

**Files:**
- Create: `roles/desktop/tasks/gnome.yml`

- [ ] **Step 1: Create roles/desktop/tasks/gnome.yml**

```yaml
- name: Install GNOME minimal desktop packages
  ansible.builtin.apt:
    name: "{{ desktop_gnome_packages }}"
    state: present
    update_cache: true
  become: true

- name: Set GDM3 as default display manager
  ansible.builtin.debconf:
    name: gdm3
    question: shared/default-x-display-manager
    value: gdm3
    vtype: select
  become: true
```

- [ ] **Step 2: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: both pass

- [ ] **Step 3: Commit**

```bash
git add roles/desktop/tasks/gnome.yml
git commit -m "feat(desktop): add GNOME minimal desktop installation task"
```

---

## Task 4: Desktop Role — xrdp

**Files:**
- Create: `roles/desktop/tasks/xrdp.yml`
- Create: `roles/desktop/handlers/main.yml`
- Create: `roles/desktop/templates/startwm.sh.j2`
- Create: `roles/desktop/files/45-allow-colord.pkla`

- [ ] **Step 1: Create roles/desktop/templates/startwm.sh.j2**

```bash
#!/bin/sh
# Managed by Ansible — do not edit manually
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
. /etc/X11/Xsession
```

- [ ] **Step 2: Create roles/desktop/files/45-allow-colord.rules**

This suppresses the "Authentication is required to create a color managed device" popup that appears every GNOME xrdp session. Uses the modern polkit `.rules` format (`.pkla` was dropped in polkit 121+, which ships with Ubuntu 24.04+):

```javascript
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.color-manager.create-device" ||
        action.id == "org.freedesktop.color-manager.create-profile" ||
        action.id == "org.freedesktop.color-manager.delete-device" ||
        action.id == "org.freedesktop.color-manager.delete-profile" ||
        action.id == "org.freedesktop.color-manager.modify-device" ||
        action.id == "org.freedesktop.color-manager.modify-profile") {
        return polkit.Result.YES;
    }
});
```

- [ ] **Step 3: Create roles/desktop/handlers/main.yml**

```yaml
- name: Restart xrdp
  ansible.builtin.systemd:
    name: xrdp
    state: restarted
  become: true
```

- [ ] **Step 4: Create roles/desktop/tasks/xrdp.yml**

```yaml
- name: Install xrdp and xorgxrdp
  ansible.builtin.apt:
    name:
      - xrdp
      - xorgxrdp
    state: present
    update_cache: true
  become: true

- name: Add xrdp user to ssl-cert group
  ansible.builtin.user:
    name: xrdp
    groups: ssl-cert
    append: true
  become: true

- name: Deploy xrdp session start script
  ansible.builtin.template:
    src: startwm.sh.j2
    dest: /etc/xrdp/startwm.sh
    owner: root
    group: root
    mode: "0755"
  become: true
  notify: Restart xrdp

- name: Ensure polkit rules directory exists
  ansible.builtin.file:
    path: /etc/polkit-1/rules.d
    state: directory
    owner: root
    group: root
    mode: "0755"
  become: true

- name: Deploy colord polkit rule
  ansible.builtin.copy:
    src: 45-allow-colord.rules
    dest: /etc/polkit-1/rules.d/45-allow-colord.rules
    owner: root
    group: root
    mode: "0644"
  become: true

- name: Enable and start xrdp service
  ansible.builtin.systemd:
    name: xrdp
    enabled: true
    state: started
    daemon_reload: true
  become: true
  when: not ansible_check_mode
```

- [ ] **Step 5: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: both pass

- [ ] **Step 6: Commit**

```bash
git add roles/desktop/tasks/xrdp.yml roles/desktop/handlers/main.yml roles/desktop/templates/startwm.sh.j2 roles/desktop/files/45-allow-colord.rules
git commit -m "feat(desktop): add xrdp configuration with GNOME session and polkit rule"
```

---

## Task 5: Desktop Role — Google Chrome

**Files:**
- Create: `roles/desktop/tasks/chrome.yml`

- [ ] **Step 1: Create roles/desktop/tasks/chrome.yml**

```yaml
- name: Ensure apt keyrings directory exists
  ansible.builtin.file:
    path: /etc/apt/keyrings
    state: directory
    owner: root
    group: root
    mode: "0755"
  become: true

- name: Download Google apt signing key
  ansible.builtin.get_url:
    url: https://dl.google.com/linux/linux_signing_key.pub
    dest: /tmp/google-linux-signing-key.pub
    mode: "0644"
  become: true

- name: Dearmor Google signing key into keyring
  ansible.builtin.command:
    cmd: gpg --batch --yes --dearmor -o /etc/apt/keyrings/google.gpg /tmp/google-linux-signing-key.pub
    creates: /etc/apt/keyrings/google.gpg
  become: true

- name: Add Google Chrome apt repository
  ansible.builtin.copy:
    content: "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.gpg] https://dl.google.com/linux/chrome/deb/ stable main\n"
    dest: /etc/apt/sources.list.d/google-chrome.list
    owner: root
    group: root
    mode: "0644"
  become: true

- name: Install Google Chrome
  ansible.builtin.apt:
    name: google-chrome-stable
    state: present
    update_cache: true
  become: true
```

- [ ] **Step 2: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: both pass

- [ ] **Step 3: Commit**

```bash
git add roles/desktop/tasks/chrome.yml
git commit -m "feat(desktop): add Google Chrome installation via apt repo"
```

---

## Task 6: Add Barlo Play to main.yml

**Files:**
- Modify: `main.yml`

Insert the following play after the `setup minecraft server` play and before the `configure unifi` play:

- [ ] **Step 1: Add barlo play to main.yml**

Insert after the minecraft play block:

```yaml
- name: setup barlo remote site server
  hosts: barlo
  become: true
  roles:
    - role: ansible_user
    - role: packages
    - role: users
    - role: geerlingguy.ntp
    - role: geerlingguy.security
    - role: artis3n.tailscale.machine
      when: not ansible_check_mode
    - role: desktop
    - role: uptime_kuma
```

- [ ] **Step 2: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: both pass

- [ ] **Step 3: Commit**

```bash
git add main.yml
git commit -m "feat(barlo): add barlo play to main.yml"
```

---

## Task 7: Add Barlo Task to Taskfile

**Files:**
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add barlo task to Taskfile.yml**

Insert after the `minecraft` task block:

```yaml
  barlo:
    desc: Deploy to barlo remote site server
    cmds:
      - task: ansible
        vars: { PLAYBOOK: "main.yml", LIMIT: "barlo", CLI_ARGS: "{{.CLI_ARGS}}" }
```

- [ ] **Step 2: Verify task is listed**

```bash
task --list | grep barlo
```

Expected: `barlo    Deploy to barlo remote site server`

- [ ] **Step 3: Commit**

```bash
git add Taskfile.yml
git commit -m "feat(barlo): add barlo deploy task to Taskfile"
```

---

## Task 8: Bootstrap & Deploy

> **Pre-requisite:** barlo must be reachable at 192.168.233.126 via SSH as `tommy`. Run `ssh-keyscan 192.168.233.126 >> ~/.ssh/known_hosts` first to resolve the host key verification failure.

- [ ] **Step 1: Add barlo to known_hosts**

```bash
ssh-keyscan 192.168.233.126 >> ~/.ssh/known_hosts
```

Expected: one or more host key lines appended

- [ ] **Step 2: Bootstrap barlo**

```bash
task bootstrap -- --limit barlo.tlesh.xyz -k -K
```

`-k` prompts for SSH password (tommy's password), `-K` prompts for sudo password (same root password from Doppler). This creates the `ansible` service account, installs the SSH key, and disables password auth.

Expected: play recap shows no failures

- [ ] **Step 3: Dry-run deploy**

```bash
task barlo -- --check
```

Expected: plays show expected changes, no failures. Note: tasks with `when: not ansible_check_mode` (Tailscale, xrdp start) will be skipped — this is correct.

- [ ] **Step 4: Full deploy**

```bash
task barlo
```

Expected: play recap shows no failures. GNOME, xrdp, Chrome, Tailscale, and Uptime Kuma all installed.

- [ ] **Step 5: Verify xrdp is listening**

```bash
ssh ansible@192.168.233.126 "systemctl is-active xrdp"
```

Expected: `active`

- [ ] **Step 6: Verify Uptime Kuma is reachable**

Open `http://192.168.233.126:3001` in a browser. Expected: Uptime Kuma setup/login screen.

- [ ] **Step 7: Verify RDP connection**

Open Microsoft Remote Desktop on your Mac. Connect to `192.168.233.126:3389` as `tommy`. Expected: GNOME desktop session launches.

- [ ] **Step 8: Enroll Tailscale**

Tailscale is installed by the play. If the `artis3n.tailscale.machine` role requires a one-time auth key that wasn't pre-configured in Doppler for barlo, run on the box:

```bash
ssh ansible@192.168.233.126 "sudo tailscale up"
```

Follow the auth URL in the output to complete enrollment on `dunker-hops.ts.net`.

---

## Post-Move Steps (after physical relocation to bakery)

- [ ] Update `ansible_host` in `./hosts` from `192.168.233.126` to `barlo.dunker-hops.ts.net`
- [ ] Run `task barlo -- --check` to verify Ansible can still reach barlo over Tailscale
- [ ] Set DHCP reservations for Chromecast devices in bakery UniFi
- [ ] Log in to Uptime Kuma at `http://barlo.dunker-hops.ts.net:3001` and add monitors:
  - HTTP(S) check → `https://google.com` (internet connectivity)
  - Ping → bakery router/gateway IP
  - Ping → each Chromecast IP (after DHCP reservations set)
- [ ] Add Pushover notification channel in Uptime Kuma Settings → Notifications
- [ ] Verify RDP from Mac: Microsoft Remote Desktop → `barlo.dunker-hops.ts.net:3389`
