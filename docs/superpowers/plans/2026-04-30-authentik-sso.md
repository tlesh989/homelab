# Authentik SSO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Authentik as an OIDC identity provider on kaz and configure native SSO login for Grafana, n8n, and FreshRSS.

**Architecture:** Authentik runs as four Docker containers on kaz (server, worker, PostgreSQL, Redis) on an isolated `authentik` Docker network. Caddy proxies `authentik.tlesh.xyz` to kaz:9000. Each app (Grafana, n8n, FreshRSS) uses native OIDC env vars — no forward-auth proxy. The Authentik application and provider for each service require a one-time manual setup in the Authentik UI; client credentials are then stored in Doppler and injected into service roles.

**Tech Stack:** Ansible, Docker (community.docker), Authentik 2025.2, PostgreSQL 16, Redis 7, Caddy, Pi-hole

**Prerequisite:** PR 1 (infrastructure-cleanup) must be merged and deployed first. Plan 2 adds env vars to the Grafana container that Plan 1 first introduces.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `roles/authentik/defaults/main.yml` | Create | Role configuration variables |
| `roles/authentik/tasks/main.yml` | Create | All container deployment tasks |
| `roles/caddy/defaults/main.yml` | Modify | Add authentik to caddy_services |
| `roles/pi-hole/defaults/main.yml` | Modify | Add authentik.tlesh.xyz DNS record |
| `roles/glance/templates/glance.yml.j2` | Modify | Add Authentik to infrastructure widget |
| `main.yml` | Modify | Add authentik role to kaz host |
| `roles/monitoring/tasks/main.yml` | Modify | Add Grafana OIDC env vars |
| `roles/n8n/tasks/main.yml` | Modify | Add n8n OIDC env vars |
| `roles/freshrss/tasks/main.yml` | Modify | Add FreshRSS OIDC env vars |

---

## Task 1: Scaffold Authentik Role

**Files:**
- Create: `roles/authentik/defaults/main.yml`
- Create: `roles/authentik/tasks/main.yml`

- [ ] **Step 1: Create role directory structure**

```bash
mkdir -p roles/authentik/{defaults,tasks}
```

- [ ] **Step 2: Create defaults/main.yml**

Create `roles/authentik/defaults/main.yml`:

```yaml
---
authentik_version: "2025.2"
authentik_port: 9000
authentik_data_path: /opt/authentik
authentik_media_path: /opt/authentik/media
authentik_certs_path: /opt/authentik/certs
authentik_postgres_path: /opt/authentik/postgres
authentik_hostname: authentik.tlesh.xyz
authentik_network: authentik

authentik_secret_key: "{{ lookup('env', 'AUTHENTIK_SECRET_KEY') }}"
authentik_postgres_password: "{{ lookup('env', 'AUTHENTIK_POSTGRES_PASSWORD') }}"
```

- [ ] **Step 3: Create tasks/main.yml with directory and network setup**

Create `roles/authentik/tasks/main.yml`:

```yaml
---
- name: Install Docker Python SDK
  ansible.builtin.package:
    name: python3-docker
    state: present
  become: true

- name: Create Authentik directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "1000"
    group: "1000"
    mode: "0755"
  loop:
    - "{{ authentik_data_path }}"
    - "{{ authentik_media_path }}"
    - "{{ authentik_certs_path }}"
  become: true

- name: Create Authentik PostgreSQL directory
  ansible.builtin.file:
    path: "{{ authentik_postgres_path }}"
    state: directory
    owner: "999"
    group: "999"
    mode: "0700"
  become: true

- name: Create Authentik Docker network
  community.docker.docker_network:
    name: "{{ authentik_network }}"
    state: present
  become: true
  when: not ansible_check_mode

- name: Deploy PostgreSQL container
  community.docker.docker_container:
    name: authentik-postgres
    image: "docker.io/library/postgres:16-alpine"
    state: started
    restart_policy: always
    networks:
      - name: "{{ authentik_network }}"
    volumes:
      - "{{ authentik_postgres_path }}:/var/lib/postgresql/data"
    env:
      POSTGRES_DB: "authentik"
      POSTGRES_USER: "authentik"
      POSTGRES_PASSWORD: "{{ authentik_postgres_password | string }}"
  become: true
  when: not ansible_check_mode

- name: Deploy Redis container
  community.docker.docker_container:
    name: authentik-redis
    image: "docker.io/library/redis:7-alpine"
    state: started
    restart_policy: always
    networks:
      - name: "{{ authentik_network }}"
    command: "--save 60 1 --loglevel warning"
  become: true
  when: not ansible_check_mode

- name: Deploy Authentik server container
  community.docker.docker_container:
    name: authentik-server
    image: "ghcr.io/goauthentik/server:{{ authentik_version }}"
    state: started
    restart_policy: always
    command: server
    networks:
      - name: "{{ authentik_network }}"
    ports:
      - "{{ authentik_port | string }}:9000"
    volumes:
      - "{{ authentik_media_path }}:/media"
      - "{{ authentik_certs_path }}:/certs"
    env:
      AUTHENTIK_REDIS__HOST: "authentik-redis"
      AUTHENTIK_POSTGRESQL__HOST: "authentik-postgres"
      AUTHENTIK_POSTGRESQL__USER: "authentik"
      AUTHENTIK_POSTGRESQL__NAME: "authentik"
      AUTHENTIK_POSTGRESQL__PASSWORD: "{{ authentik_postgres_password | string }}"
      AUTHENTIK_SECRET_KEY: "{{ authentik_secret_key | string }}"
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
  become: true
  when: not ansible_check_mode

- name: Deploy Authentik worker container
  community.docker.docker_container:
    name: authentik-worker
    image: "ghcr.io/goauthentik/server:{{ authentik_version }}"
    state: started
    restart_policy: always
    command: worker
    networks:
      - name: "{{ authentik_network }}"
    volumes:
      - "{{ authentik_media_path }}:/media"
      - "{{ authentik_certs_path }}:/certs"
      - "/var/run/docker.sock:/var/run/docker.sock"
    env:
      AUTHENTIK_REDIS__HOST: "authentik-redis"
      AUTHENTIK_POSTGRESQL__HOST: "authentik-postgres"
      AUTHENTIK_POSTGRESQL__USER: "authentik"
      AUTHENTIK_POSTGRESQL__NAME: "authentik"
      AUTHENTIK_POSTGRESQL__PASSWORD: "{{ authentik_postgres_password | string }}"
      AUTHENTIK_SECRET_KEY: "{{ authentik_secret_key | string }}"
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
  become: true
  when: not ansible_check_mode
```

- [ ] **Step 4: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add roles/authentik/
git commit -m "feat: add Authentik SSO role with PostgreSQL and Redis"
```

---

## Task 2: Add Authentik to Caddy + Pi-hole + Glance + Playbook

**Files:**
- Modify: `roles/caddy/defaults/main.yml`
- Modify: `roles/pi-hole/defaults/main.yml`
- Modify: `roles/glance/templates/glance.yml.j2`
- Modify: `main.yml`

- [ ] **Step 1: Add authentik to caddy_services**

In `roles/caddy/defaults/main.yml`, append to the `caddy_services` list:

```yaml
  - name: authentik
    upstream: "192.168.233.10:9000"
```

- [ ] **Step 2: Add authentik DNS record to Pi-hole**

In `roles/pi-hole/defaults/main.yml`, append to `pihole_local_hosts`:

```yaml
  - "192.168.233.17 authentik.tlesh.xyz"
```

- [ ] **Step 3: Add Authentik to Glance infrastructure widget**

In `roles/glance/templates/glance.yml.j2`, find the infrastructure monitor widget service list and add Authentik after FreshRSS (before Seerr):

```yaml
              - title: Authentik
                url: https://authentik.tlesh.xyz
                icon: si:authelia
```

Note: Simple Icons does not have an Authentik icon; `si:authelia` is the closest available alternative. Alternatively use `di:authentik` if Glance supports DiceBear icons, or omit the icon field.

- [ ] **Step 4: Add authentik role to kaz in main.yml**

In `main.yml`, find the kaz host block and add `authentik` to the roles list, positioned after `monitoring` and before `n8n`:

```yaml
    roles:
      - monitoring
      - authentik
      - n8n
      - freshrss
      ...
```

- [ ] **Step 5: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add roles/caddy/defaults/main.yml \
        roles/pi-hole/defaults/main.yml \
        roles/glance/templates/glance.yml.j2 \
        main.yml
git commit -m "feat: integrate Authentik into Caddy, Pi-hole, Glance, and playbook"
```

---

## Task 3: Prepare Doppler Secrets and Deploy Authentik

- [ ] **Step 1: Generate Authentik secret key and add to Doppler**

```bash
# Generate a secure 50-character secret key
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

Add output to Doppler as `AUTHENTIK_SECRET_KEY`.

- [ ] **Step 2: Generate Postgres password and add to Doppler**

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Add output to Doppler as `AUTHENTIK_POSTGRES_PASSWORD`.

- [ ] **Step 3: Deploy Authentik**

```bash
doppler run -- ansible-playbook main.yml --limit kaz --tags authentik
doppler run -- ansible-playbook main.yml --limit caddy,pi-hole --tags caddy,pihole
```

- [ ] **Step 4: Verify Authentik is running**

Navigate to `https://authentik.tlesh.xyz/if/flow/initial-setup/` in a browser.

Expected: Authentik initial setup wizard (create admin user).

Complete the wizard: set admin email and password, store credentials in your password manager.

---

## Task 4: Create OIDC Applications in Authentik UI

These steps are manual one-time configuration in the Authentik web UI. Perform them after Authentik is deployed (Task 3).

### Grafana OIDC App

- [ ] **Step 1: Create Grafana provider in Authentik**

1. Log in to `https://authentik.tlesh.xyz`
2. Go to **Admin Interface** → **Applications** → **Providers** → **Create**
3. Select **OAuth2/OpenID Provider**
4. Configure:
   - Name: `Grafana`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://grafana.tlesh.xyz/login/generic_oauth`
   - Scopes: `email`, `openid`, `profile`
5. Save. Copy the **Client ID** and **Client Secret**.

- [ ] **Step 2: Create Grafana application**

1. Go to **Applications** → **Applications** → **Create**
2. Configure:
   - Name: `Grafana`
   - Slug: `grafana`
   - Provider: select the Grafana provider just created
3. Save.

- [ ] **Step 3: Store Grafana OIDC credentials in Doppler**

```
GRAFANA_OIDC_CLIENT_ID=<client id from step 1>
GRAFANA_OIDC_CLIENT_SECRET=<client secret from step 1>
```

### n8n OIDC App

- [ ] **Step 4: Create n8n provider in Authentik**

1. Go to **Providers** → **Create** → **OAuth2/OpenID Provider**
2. Configure:
   - Name: `n8n`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://n8n.tlesh.xyz/rest/oauth2-credential/callback`
   - Scopes: `email`, `openid`, `profile`
3. Save. Copy **Client ID** and **Client Secret**.

- [ ] **Step 5: Create n8n application**

1. Go to **Applications** → **Create**
2. Configure: Name `n8n`, Slug `n8n`, Provider: n8n provider
3. Save.

- [ ] **Step 6: Store n8n OIDC credentials in Doppler**

```
N8N_OIDC_CLIENT_ID=<client id>
N8N_OIDC_CLIENT_SECRET=<client secret>
```

### FreshRSS OIDC App

- [ ] **Step 7: Create FreshRSS provider in Authentik**

1. Go to **Providers** → **Create** → **OAuth2/OpenID Provider**
2. Configure:
   - Name: `FreshRSS`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://freshrss.tlesh.xyz/i/oidc/`
   - Scopes: `email`, `openid`, `profile`
3. Save. Copy **Client ID** and **Client Secret**.

- [ ] **Step 8: Create FreshRSS application**

1. Go to **Applications** → **Create**
2. Configure: Name `FreshRSS`, Slug `freshrss`, Provider: FreshRSS provider
3. Save.

- [ ] **Step 9: Store FreshRSS OIDC credentials in Doppler**

```
FRESHRSS_OIDC_CLIENT_ID=<client id>
FRESHRSS_OIDC_CLIENT_SECRET=<client secret>
```

---

## Task 5: Configure Grafana OIDC

**Files:**
- Modify: `roles/monitoring/tasks/main.yml`

- [ ] **Step 1: Add OIDC env vars to Grafana container task**

In `roles/monitoring/tasks/main.yml`, in the Grafana container's `env:` section (already has PUSHOVER vars from Plan 1), add:

```yaml
    env:
      PUSHOVER_APP_TOKEN: "{{ lookup('env', 'PUSHOVER_APP_TOKEN') }}"
      PUSHOVER_USER_KEY: "{{ lookup('env', 'PUSHOVER_USER_KEY') }}"
      GF_AUTH_GENERIC_OAUTH_ENABLED: "true"
      GF_AUTH_GENERIC_OAUTH_NAME: "Authentik"
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: "{{ lookup('env', 'GRAFANA_OIDC_CLIENT_ID') }}"
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: "{{ lookup('env', 'GRAFANA_OIDC_CLIENT_SECRET') }}"
      GF_AUTH_GENERIC_OAUTH_SCOPES: "openid email profile"
      GF_AUTH_GENERIC_OAUTH_AUTH_URL: "https://authentik.tlesh.xyz/application/o/authorize/"
      GF_AUTH_GENERIC_OAUTH_TOKEN_URL: "https://authentik.tlesh.xyz/application/o/token/"
      GF_AUTH_GENERIC_OAUTH_API_URL: "https://authentik.tlesh.xyz/application/o/userinfo/"
      GF_AUTH_SIGNOUT_REDIRECT_URL: "https://authentik.tlesh.xyz/application/o/grafana/end-session/"
      GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH: "contains(groups, 'admin') && 'Admin' || 'Viewer'"
      GF_AUTH_GENERIC_OAUTH_AUTO_LOGIN: "false"
```

- [ ] **Step 2: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add roles/monitoring/tasks/main.yml
git commit -m "feat: add Authentik OIDC login to Grafana"
```

---

## Task 6: Configure n8n OIDC

**Files:**
- Modify: `roles/n8n/tasks/main.yml`

- [ ] **Step 1: Verify n8n OIDC env var names**

Before editing, confirm the correct env var names for your n8n version:

```bash
doppler run -- docker exec n8n n8n --help 2>/dev/null | grep -i oidc || true
# Also check: https://docs.n8n.io/hosting/configuration/environment-variables/
```

n8n v1+ supports OIDC via the env vars below. If your version differs, adjust accordingly.

- [ ] **Step 2: Add OIDC env vars to n8n container task**

In `roles/n8n/tasks/main.yml`, in the `env:` section of the n8n container, append:

```yaml
      N8N_AUTH_OIDC_ENABLED: "true"
      N8N_AUTH_OIDC_ISSUER_URL: "https://authentik.tlesh.xyz/application/o/n8n/"
      N8N_AUTH_OIDC_CLIENT_ID: "{{ lookup('env', 'N8N_OIDC_CLIENT_ID') }}"
      N8N_AUTH_OIDC_CLIENT_SECRET: "{{ lookup('env', 'N8N_OIDC_CLIENT_SECRET') }}"
      N8N_AUTH_OIDC_REDIRECT_URL: "https://n8n.tlesh.xyz/rest/oauth2-credential/callback"
```

- [ ] **Step 3: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add roles/n8n/tasks/main.yml
git commit -m "feat: add Authentik OIDC login to n8n"
```

---

## Task 7: Configure FreshRSS OIDC

**Files:**
- Modify: `roles/freshrss/tasks/main.yml`

- [ ] **Step 1: Add OIDC env vars to FreshRSS container task**

In `roles/freshrss/tasks/main.yml`, in the `env:` section of the FreshRSS container, append:

```yaml
      OIDC_ENABLED: "1"
      OIDC_PROVIDER_METADATA_URL: "https://authentik.tlesh.xyz/application/o/freshrss/.well-known/openid-configuration"
      OIDC_CLIENT_ID: "{{ lookup('env', 'FRESHRSS_OIDC_CLIENT_ID') }}"
      OIDC_CLIENT_SECRET: "{{ lookup('env', 'FRESHRSS_OIDC_CLIENT_SECRET') }}"
      OIDC_SCOPES: "openid email profile"
      OIDC_X_FORWARDED_HEADERS: "HTTP_X_FORWARDED_PORT HTTP_X_FORWARDED_PROTO HTTP_FORWARDED"
      OIDC_LOGOUT_URL: "https://authentik.tlesh.xyz/application/o/freshrss/end-session/"
```

Note: `OIDC_X_FORWARDED_HEADERS` is required because FreshRSS sits behind the Caddy reverse proxy.

- [ ] **Step 2: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add roles/freshrss/tasks/main.yml
git commit -m "feat: add Authentik OIDC login to FreshRSS"
```

---

## Final Steps

- [ ] **Run CodeRabbit review**

```bash
coderabbit review --plain --base main
```

Fix any issues before opening the PR.

- [ ] **Open PR**

```bash
git push -u origin HEAD
gh pr create --title "feat: Authentik SSO with OIDC for Grafana, n8n, FreshRSS" \
  --body "Deploys Authentik identity provider on kaz. Adds OIDC native login to Grafana, n8n, and FreshRSS. Requires one-time manual OIDC app setup in Authentik UI per the plan doc (Task 4)."
```

- [ ] **Deploy service OIDC configs**

After Authentik apps are created and Doppler secrets set (Task 4):

```bash
doppler run -- ansible-playbook main.yml --limit kaz --tags monitoring,n8n,freshrss
```

- [ ] **Verify OIDC logins**

1. `https://grafana.tlesh.xyz` → click "Sign in with Authentik" → redirects to Authentik → returns to Grafana logged in
2. `https://n8n.tlesh.xyz` → OIDC login flow works
3. `https://freshrss.tlesh.xyz` → OIDC login flow works

- [ ] **Verify Grafana role mapping**

- Users in Authentik `admin` group get Grafana Admin role
- All other users get Viewer role
- Create an `admin` group in Authentik UI (Admin Interface → Directory → Groups) and add your user to it
