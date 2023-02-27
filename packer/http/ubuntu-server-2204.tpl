#cloud-config
autoinstall:
  # https://ubuntu.com/server/docs/install/autoinstall-reference
  version: 1
  refresh-installer:
    update: yes
  storage:
    layout:
      name: lvm
    swap:
      size: 0
  ssh:
    install-server: true
    allow-pw: true
    authorized-keys:
      - {{ op://Private/ssh/id_rsa.pub }}
      - {{ op://Private/id_rsa2022/public key }}
  packages:
    - qemu-guest-agent
  user-data:
    package_upgrade: false
    timezone: America/Detroit
    users: 
      - name: op://Private/ssh/username
        password: op://Private/ssh/mkpasswd
        groups: [adm, sudo]
        lock_passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
