#!/usr/bin/env bash
# Validates Docker image repositories exist in their registries.
# Supports ghcr.io (anonymous token flow) and Docker Hub (hub.docker.com API).
# Skips Jinja2-templated repos and warns on unrecognized custom registries.
set -euo pipefail

FAILED=0
declare -a CHECKED=()

extract_images() {
  grep -oE 'image:[[:space:]]+"?[^"[:space:]{]+' "$1" 2>/dev/null \
    | sed 's/image:[[:space:]]*//' \
    | sed 's/"//g' \
    | grep -vE '^(true|false|yes|no|null|~)$' \
    || true
}

already_checked() {
  local img="$1"
  local i
  for i in ${CHECKED[@]+"${CHECKED[@]}"}; do
    [[ "$i" == "$img" ]] && return 0
  done
  return 1
}

check_ghcr() {
  local full_ref="$1"
  local repo tag token http_code
  repo="${full_ref%%:*}"
  tag="${full_ref#*:}"
  [[ "$tag" == "$full_ref" ]] && tag="latest"
  token=$(curl -s --max-time 10 "https://ghcr.io/token?scope=repository:${repo}:pull" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true)
  if [[ -z "$token" ]]; then
    echo "  WARN (could not get GHCR token, skipping): ghcr.io/${repo}:${tag}"
    return 0
  fi
  # Validate the specific tag via manifests endpoint
  http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/${repo}/manifests/${tag}" 2>/dev/null || echo "ERR")
  case "$http_code" in
    200)  echo "  OK (200): ghcr.io/${repo}:${tag}" ;;
    404)  echo "  FAIL 404: ghcr.io/${repo}:${tag}"; FAILED=1 ;;
    401)  echo "  WARN (private, skipping): ghcr.io/${repo}:${tag}" ;;
    ERR)  echo "  WARN (unreachable, skipping): ghcr.io/${repo}:${tag}" ;;
    *)    echo "  OK (${http_code}): ghcr.io/${repo}:${tag}" ;;
  esac
}

check_dockerhub() {
  local full_ref="$1"
  local repo tag http_code
  repo="${full_ref%%:*}"
  tag="${full_ref#*:}"
  [[ "$tag" == "$full_ref" ]] && tag="latest"
  # Single-word images (e.g. "nginx") live under the "library" namespace
  if [[ "$repo" != */* ]]; then
    repo="library/${repo}"
  fi
  # Validate the specific tag via the tags API
  http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
    "https://hub.docker.com/v2/repositories/${repo}/tags/${tag}/" 2>/dev/null || echo "ERR")
  case "$http_code" in
    200)  echo "  OK (200): docker.io/${repo}:${tag}" ;;
    404)  echo "  FAIL 404: docker.io/${repo}:${tag}"; FAILED=1 ;;
    ERR)  echo "  WARN (unreachable, skipping): docker.io/${repo}:${tag}" ;;
    *)    echo "  OK (${http_code}): docker.io/${repo}:${tag}" ;;
  esac
}

for file in "$@"; do
  [[ -f "$file" ]] || continue
  while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    [[ "$image" == *"{{"* ]] && continue
    # Jinja2-templated tags produce "image:" (regex stops at {) — skip them
    [[ "$image" == *: ]] && continue
    already_checked "$image" && continue
    CHECKED+=("$image")

    repo="${image%%:*}"
    first="${repo%%/*}"
    if [[ "$first" == *"."* ]]; then
      if [[ "$image" == ghcr.io/* ]]; then
        check_ghcr "${image#ghcr.io/}"
      else
        echo "  SKIP (custom registry, cannot validate): ${image}"
      fi
    else
      check_dockerhub "$image"
    fi
  done < <(extract_images "$file")
done

exit "$FAILED"
