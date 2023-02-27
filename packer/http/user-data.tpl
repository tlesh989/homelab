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
  timezone: America/Detroit
  identity:
    hostname: ubuntu-server
    password: op://Private/ssh/mkpasswd
    username: op://Private/ssh/username
