#!/usr/bin/env bash

sudo rm /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id
sudo apt -y autoremove --purge
sudo apt -y clean
sudo apt -y autoclean
sudo cloud-init clean
sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
sudo sync