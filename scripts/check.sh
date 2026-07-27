#!/usr/bin/env bash
# Preflight self-check for the vision-fallback skill.
#
# Verifies, in order:
#   1. Required shell deps are present (curl, jq, file, base64).
#   2. API key can be resolved for the configured provider (ark|openai).
#   3. The configured endpoint is reachable (a quick TLS connect).
#
# Exits 0 only when all checks pass. On failure, prints a clear, actionable
# message to stderr and exits non-zero. Never prints the key value.
#
# Usage:  ./scripts/check.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS=0

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

: "${VISION_PROVIDER:=ark}"

# --- 1. Shell dependencies ---
MISSING=()
for c in curl jq file base64; do
  if ! command -v "$c" >/dev/null 2>&1; then
    MISSING+=("$c")
  fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
  red "FAIL: missing required commands: ${MISSING[*]}"
  red "       Install them (e.g. via brew/installer) and re-run."
  STATUS=1
else
  green "OK:   dependencies present (curl, jq, file, base64)"
fi

# --- 2. Provider config + API key resolution ---
# Source resolve-config.sh's logic without aborting on failure.
# We replicate the logic here so we can report all failures clearly.
case "$VISION_PROVIDER" in
  ark)
    BASE_URL="${VISION_BASE_URL:-https://ark.cn-beijing.volces.com/api/plan/v3}"
    MODEL="${VISION_MODEL:-doubao-seed-2.0-lite}"
    KEY_ENV="ARK_API_KEY"
    ;;
  openai)
    BASE_URL="${VISION_BASE_URL:-https://api.openai.com/v1}"
    MODEL="${VISION_MODEL:-gpt-4o-mini}"
    KEY_ENV="OPENAI_API_KEY"
    ;;
  *)
    red "FAIL: VISION_PROVIDER='$VISION_PROVIDER' is invalid. Use 'ark' or 'openai'."
    exit 1
    ;;
esac

# Helper: safely parse KEY=VALUE from a dotenv file (no sourcing/exec)
_parse_env() {
  local file="$1" key="$2"
  grep -E "^\s*${key}=" "$file" 2>/dev/null | \
    head -1 | \
    sed -E "s/^\s*${key}=//; s/^\"(.*)\"$/\1/; s/^'(.*)'$/\1/"
}

RESOLVED_KEY=""
KEY_SOURCE=""
if [ -n "${VISION_API_KEY:-}" ]; then
  RESOLVED_KEY="$VISION_API_KEY"
  KEY_SOURCE="VISION_API_KEY"
else
  eval "prov_key=\"\${${KEY_ENV}:-}\""
  if [ -n "$prov_key" ]; then
    RESOLVED_KEY="$prov_key"
    KEY_SOURCE="$KEY_ENV"
  else
    : "${VISION_ENV_FILE:=}"
    for f in "$VISION_ENV_FILE" "$HOME/.env_vars" "/root/.env_vars"; do
      [ -n "$f" ] && [ -f "$f" ] || continue
      # Check VISION_API_KEY first
      _val="$(_parse_env "$f" VISION_API_KEY)"
      if [ -n "$_val" ]; then
        RESOLVED_KEY="$_val"
        KEY_SOURCE="$f:VISION_API_KEY"
        break
      fi
      # Then provider-specific
      _val="$(_parse_env "$f" "$KEY_ENV")"
      if [ -n "$_val" ]; then
        RESOLVED_KEY="$_val"
        KEY_SOURCE="$f:$KEY_ENV"
        break
      fi
    done
  fi
fi
unset -f _parse_env

if [ -z "$RESOLVED_KEY" ]; then
  red "FAIL: No API key resolved for provider '$VISION_PROVIDER'."
  red "       Tried: VISION_API_KEY, $KEY_ENV, dotenv files (~/.env_vars)."
  red "       Set one of:"
  red "         export VISION_API_KEY=...       # works for any provider"
  red "         export ${KEY_ENV}=...           # provider-specific"
  red "       Or store in ~/.env_vars."
  red "       See references/configuration.md."
  STATUS=1
else
  green "OK:   provider=$VISION_PROVIDER model=$MODEL key=$KEY_SOURCE (len ${#RESOLVED_KEY})"
fi

# --- 3. Endpoint reachability ---
HOST="$(printf '%s' "$BASE_URL" | sed -E 's|https?://([^/:]+).*|\1|')"
# Preserve the original scheme (http or https) for the reachability check.
SCHEME="$(printf '%s' "$BASE_URL" | sed -E 's|^(https?)://.*|\1|')"
[ -z "$SCHEME" ] && SCHEME="https"
if command -v curl >/dev/null 2>&1; then
  if curl -sS --connect-timeout 5 --max-time 8 \
        "${SCHEME}://${HOST}/" -o /dev/null 2>/dev/null; then
    green "OK:   endpoint reachable (${SCHEME}://${HOST})"
  else
    yellow "WARN: could not reach ${SCHEME}://${HOST} within 5s."
    yellow "      Check network / region reachability. The API call may still fail."
    # Reachability is a warning, not a hard failure (could be transient / proxied).
  fi
fi

# --- Summary ---
if [ "$STATUS" -ne 0 ]; then
  red ""
  red "Preflight FAILED. Fix the issues above before calling ./scripts/call-api.sh."
  red "Do NOT substitute this skill with local OCR (tesseract) - it cannot do"
  red "visual/layout understanding. Configure the missing prerequisite instead."
  exit "$STATUS"
fi

green ""
green "Preflight OK. Ready to run ./scripts/call-api.sh"
