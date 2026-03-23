# Glance Tailscale TLS

**Date:** 2026-03-22
**Branch:** `feat/glance-tailscale-tls`

## Decision

Add Tailscale to the Glance LXC and configure Glance to serve HTTPS on port 443 using a Tailscale-issued certificate. This eliminates browser SSL warnings when accessing the dashboard.

## Why

Glance was accessible only over plain HTTP on port 8080 (`http://192.168.233.22:8080`). Browsers increasingly warn on non-HTTPS pages, and there was no clean way to get a valid certificate without either a public domain or a VPN-issued cert. Tailscale provides valid, browser-trusted HTTPS certificates for any node on the tailnet via `tailscale cert`, making this the simplest solution with no public exposure.

## Access URL

`https://glance.dunker-hops.ts.net` (port 443 — no port suffix needed)

## What Changed

- `artis3n.tailscale.machine` role added to the glance play in `main.yml`
- `tailscale_authkey` added to `group_vars/glance.yml` (reads `TAILSCALE_KEY` from Doppler)
- `glance_port` changed from `8080` to `443` in `roles/glance/defaults/main.yml`
- New defaults: `glance_hostname`, `glance_tls_cert_dir`
- New tasks in `roles/glance/tasks/main.yml`: create cert directory, issue cert via `tailscale cert`, weekly cron for renewal
- `roles/glance/templates/glance.yml.j2` server block updated with `tls:` config

## Cert Renewal

A weekly cron job (Sunday 00:00) runs `tailscale cert` and restarts Glance if the cert was renewed. Tailscale certs are valid for ~90 days; weekly renewal checks are well within that window.
