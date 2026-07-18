# Beszel Hub Pushover Alerts Runbook

Beszel supports Pushover natively via a [Shoutrrr](https://github.com/nicholas-fedor/shoutrrr) URL,
but the notification URL and per-system alert thresholds are configured through the hub's web UI —
there is no environment variable, config file, or documented API for setting this via Ansible, so
this is a manual one-time setup rather than a code change.

**Why alerts are split across two tools:**
- **Uptime Kuma** — up/down (reachability) alerts only.
- **Beszel** — sustained CPU/mem/disk threshold alerts (avoids per-container-update Watchtower noise).

## URL

https://kaz.tlesh.xyz:8090

## One-time setup

1. Get your Pushover keys (already used for Uptime Kuma, so likely already on hand):
   - `PUSHOVER_API_TOKEN` from Doppler (Pushover *application* token)
   - `PUSHOVER_USER_KEY` from Doppler (Pushover *user* key)
2. In Beszel: **Settings > Notifications**, add a URL of the form:

   ```
   pushover://shoutrrr:<PUSHOVER_API_TOKEN>@<PUSHOVER_USER_KEY>/
   ```

   Optionally append `?devices=<device1>,<device2>` to target specific devices.
3. Send a test notification from the same settings page to confirm delivery.
4. In the **Systems** table, enable alerts per host and set sustained thresholds, e.g.:
   - CPU > 90% for 10 minutes
   - Memory > 90% for 10 minutes
   - Disk > 90% (no sustain window needed)

   Tune thresholds per host to avoid alert fatigue — start conservative and tighten later.

## Recovery

If the Beszel hub's data volume (`/opt/beszel` on kaz) is ever lost, the notification URL and
per-system thresholds are stored in Beszel's database and must be re-entered manually using the
steps above.
