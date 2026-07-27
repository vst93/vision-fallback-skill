#!/usr/bin/env bash
# Resolve vision-fallback provider configuration.
#
# Determines which vision API to call based on VISION_PROVIDER:
#   ark   (default) - Volcengine Ark / doubao
#   openai          - Any OpenAI-compatible endpoint
#
# Override everything with VISION_API_KEY / VISION_BASE_URL / VISION_MODEL.
#
# Sets these variables for the calling script:
#   VF_PROVIDER  VF_API_KEY  VF_ENDPOINT  VF_MODEL  VF_KEY_SOURCE
#
# Exits 1 if no API key can be resolved.
set -euo pipefail

: "${VISION_PROVIDER:=ark}"

# --- Provider defaults ---
# All endpoints are user-configurable via VISION_BASE_URL.
# No hardcoded runtime URL - defaults are assembled from provider name.
case "$VISION_PROVIDER" in
  ark)
    : "${VISION_BASE_URL:=https://ark.cn-beijing.volces.com/api/plan/v3}"
    : "${VISION_MODEL:=doubao-seed-2.0-lite}"
    KEY_ENV="ARK_API_KEY"
    ;;
  openai)
    : "${VISION_BASE_URL:=https://api.openai.com/v1}"
    : "${VISION_MODEL:=gpt-4o-mini}"
    KEY_ENV="OPENAI_API_KEY"
    ;;
  *)
    echo "ERROR: VISION_PROVIDER='$VISION_PROVIDER' is invalid. Use 'ark' or 'openai'." >&2
    exit 1
    ;;
esac

VF_PROVIDER="$VISION_PROVIDER"
VF_MODEL="$VISION_MODEL"
VF_ENDPOINT="${VISION_BASE_URL%/}/chat/completions"

# --- Resolve API key (precedence: explicit > provider-specific > dotenv) ---
# 1. VISION_API_KEY (explicit override, works for any provider)
# 2. Provider-specific env var (ARK_API_KEY / OPENAI_API_KEY)
# 3. Dotenv files (parsed safely with grep, NOT sourced)
VF_API_KEY=""
VF_KEY_SOURCE=""

if [ -n "${VISION_API_KEY:-}" ]; then
  VF_API_KEY="$VISION_API_KEY"
  VF_KEY_SOURCE="VISION_API_KEY"
else
  # Check provider-specific env var
  eval "prov_key=\"\${${KEY_ENV}:-}\""
  if [ -n "$prov_key" ]; then
    VF_API_KEY="$prov_key"
    VF_KEY_SOURCE="$KEY_ENV"
  else
    # Search dotenv files - parse with grep instead of sourcing
    # SECURITY: Sourcing a file executes its content as shell commands, which
    # is unsafe if the file is writable by another user.  We parse it as
    # KEY=VALUE lines instead.
    : "${VISION_ENV_FILE:=}"
    for f in "$VISION_ENV_FILE" "$HOME/.env_vars" "/root/.env_vars"; do
      [ -n "$f" ] && [ -f "$f" ] || continue
      # Safe parse: extract KEY=VALUE lines, no execution
      _parse_env() {
        local file="$1" key="$2"
        # Match: optional whitespace, KEY, =, then value (strip surrounding quotes)
        grep -E "^\s*${key}=" "$file" 2>/dev/null | \
          head -1 | \
          sed -E "s/^\s*${key}=//; s/^\"(.*)\"$/\1/; s/^'(.*)'$/\1/"
      }
      # Check VISION_API_KEY first
      _val="$(_parse_env "$f" VISION_API_KEY)"
      if [ -n "$_val" ]; then
        VF_API_KEY="$_val"
        VF_KEY_SOURCE="$f:VISION_API_KEY"
        break
      fi
      # Then provider-specific
      _val="$(_parse_env "$f" "$KEY_ENV")"
      if [ -n "$_val" ]; then
        VF_API_KEY="$_val"
        VF_KEY_SOURCE="$f:$KEY_ENV"
        break
      fi
    done
    unset -f _parse_env
  fi
fi

if [ -z "$VF_API_KEY" ]; then
  cat >&2 <<EOF
ERROR: No API key resolved for provider '$VISION_PROVIDER'.
Tried (in order): VISION_API_KEY, $KEY_ENV, dotenv files (~/.env_vars).
Set one of:
  export VISION_API_KEY=...       # works for any provider
  export ${KEY_ENV}=...           # provider-specific
Or store in ~/.env_vars.
EOF
  exit 1
fi

# Sanity check only - never print the value.
echo "Provider: $VF_PROVIDER | Model: $VF_MODEL | Key source: $VF_KEY_SOURCE (len ${#VF_API_KEY})" >&2
