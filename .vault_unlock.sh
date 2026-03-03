#! /usr/bin/env bash

# Fail on any error
set -e

# Unlock Ansible Vault by retrieving the password from Doppler
doppler secrets get ANSIBLE_VAULT --plain
