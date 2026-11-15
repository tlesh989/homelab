#!/usr/bin/env bash
# Read-only: compares the Docker image tags pinned in roles/*/defaults/main.yml
# (the ones Renovate bumps) with what is running on each inventory host.
# `task check` cannot show this, because Docker tasks are skipped in check mode.
# An image pinned in several roles (dozzle, watchtower) passes when it matches any
# of those pins; Renovate bumps them together, so they normally agree.
# Exit 1: a running container is on a different tag than the repo pins.
# Exit 2: a Docker host could not be checked, or nothing was compared.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SSH_USER="${SSH_USER:-ansible}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/ansible_ed25519}"
SSH_OPTS=(-o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=5
  -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -i "${SSH_KEY}")

# "<image repo> <pinned tag>" per line.
pins="$(grep -rh -A1 'renovate: datasource=docker' roles/*/defaults/main.yml |
  awk '/depName=/ { match($0, /depName=[^ ]+/); repo = substr($0, RSTART + 8, RLENGTH - 8) }
       /^[a-z_]+: / { gsub(/"/, "", $2); print repo, $2 }' | sort -u)"

if [[ -z "${pins}" ]]; then
  echo "no Renovate-pinned Docker images found under roles/*/defaults" >&2
  exit 2
fi

# "<inventory name> <address>" for every member of the docker_hosts group.
docker_hosts="$(ansible-inventory -i hosts --list | python3 -c '
import json, sys
inv = json.load(sys.stdin)
def members(group):
    node = inv.get(group, {})
    for host in node.get("hosts", []):
        yield host
    for child in node.get("children", []):
        yield from members(child)
for host in sorted(set(members("docker_hosts"))):
    print(host, inv["_meta"]["hostvars"].get(host, {}).get("ansible_host", host))
')"

if [[ -z "${docker_hosts}" ]]; then
  echo "inventory group docker_hosts is empty or missing" >&2
  exit 2
fi

drift=0
checked=0
unreachable=0
while read -r name host; do
  # </dev/null: ssh must not swallow the rest of the host list on stdin.
  if ! images="$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${host}" \
    'sudo -n docker ps --format "{{.Image}} {{.Names}}"' 2>/dev/null </dev/null)"; then
    echo "ERROR  ${name} (${host}): could not list containers (SSH, host key or sudo)"
    unreachable=1
    continue
  fi
  while read -r image container; do
    [[ -n "${image}" ]] || continue
    repo="${image%:*}"
    tag="${image##*:}"
    wanted="$(awk -v r="${repo}" '$1 == r { print $2 }' <<<"${pins}")"
    [[ -n "${wanted}" ]] || continue
    checked=$((checked + 1))
    if grep -qxF "${tag}" <<<"${wanted}"; then
      echo "ok     ${name}: ${container} ${repo}:${tag}"
    else
      echo "DRIFT  ${name}: ${container} runs ${repo}:${tag}, repo pins $(tr '\n' ' ' <<<"${wanted}")"
      drift=1
    fi
  done <<<"${images}"
done <<<"${docker_hosts}"

if ((checked == 0)); then
  echo "no pinned containers were reachable; nothing was compared" >&2
  exit 2
fi

# A host that could not be checked may be hiding drift, so it is not a pass.
if ((drift)); then
  exit 1
fi
if ((unreachable)); then
  exit 2
fi
