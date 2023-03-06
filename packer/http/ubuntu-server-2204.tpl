#cloud-config
autoinstall:
  # https://ubuntu.com/server/docs/install/autoinstall-reference
  version: 1
  refresh-installer:
    update: false
  storage:
    layout:
      name: lvm
    swap:
      size: 0
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - qemu-guest-agent
  timezone: America/Detroit
  users-data:
    users:
      - name: op://Private/ssh/username
        passwd: "op://Private/ssh/mkpasswd"
        groups: [ adm sudo ]
        lock_passwd: false
        shell: /bin/bash
        ssh-authorized-keys:
          - {{ op://Private/ssh/id_rsa.pub }}
          - {{ op://Private/id_rsa2022/public key }}

