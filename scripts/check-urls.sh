#!/usr/bin/env bash
# Checks that HTTP(S) URLs in staged files resolve (not 404).
# Skips Jinja2 template expressions, private IPs, and localhost.
set -euo pipefail

FAILED=0
declare -a CHECKED=()

extract_urls() {
  # Skip lines containing Jinja2 expressions — URLs on those lines are often
  # truncated at '{' or embedded in string-concatenation expressions.
  # Skip lines with # nocheck annotation (for known URLs that return 404 at root).
  grep -vE '\{\{|\}\}|#\s*nocheck' "$1" 2>/dev/null | grep -oE 'https?://[^[:space:]"<>]+' || true
}

is_skippable() {
  local url="$1"
  # Skip Jinja2 template vars (belt-and-suspenders for inline expressions)
  [[ "$url" == *"{{"* ]] && return 0
  # Skip regex patterns that were extracted as URLs (e.g. https://[^\s...)
  [[ "$url" == *"["* ]] && return 0
  # Skip private/loopback addresses
  [[ "$url" =~ ^https?://(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]] && return 0
  return 1
}

already_checked() {
  local url="$1"
  local u
  for u in ${CHECKED[@]+"${CHECKED[@]}"}; do
    [[ "$u" == "$url" ]] && return 0
  done
  return 1
}

for file in "$@"; do
  [[ -f "$file" ]] || continue
  while IFS= read -r url; do
    # Strip trailing quotes/parens that wrap URLs in YAML/Markdown
    url="${url%%[\'\")\`]*}"
    [[ -z "$url" ]] && continue
    is_skippable "$url" && continue
    already_checked "$url" && continue
    CHECKED+=("$url")

    http_code=$(curl -sI --max-time 10 -L -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "ERR")

    if [[ "$http_code" == "404" ]]; then
      echo "  FAIL 404: $url"
      FAILED=1
    elif [[ "$http_code" == "ERR" ]]; then
      echo "  WARN (unreachable, skipping): $url"
    else
      echo "  OK ($http_code): $url"
    fi
  done < <(extract_urls "$file")
done

exit "$FAILED"
