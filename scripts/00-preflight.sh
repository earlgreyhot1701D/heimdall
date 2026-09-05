#!/usr/bin/env bash
# 00-preflight.sh - Block 0 pre-flight.
#
# ONE JOB: call each of the three models DIRECTLY against api.openai.com,
# bypassing Bifrost, and confirm each returns a completion.
#
# This is the ONE script in the harness that is allowed to target a provider
# domain. That is by design: the pre-flight exists precisely to prove the
# models are reachable directly, so that any denial later through the gateway
# can only have come from the gateway. 99-dryrun-checks.sh knows this script is
# the explicit exception to the localhost-only rule and shows it in the output.
#
# Model names come ONLY from .env (MODEL_ROUTINE / MODEL_STANDARD / MODEL_RESTRICTED).
# For the direct provider call we strip the "openai/" prefix, since that prefix
# is a Bifrost routing convention, not an OpenAI model id.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

PROVIDER_URL="https://api.openai.com/v1/chat/completions"
PROMPT='hello'

announce "Block 0 pre-flight: three DIRECT calls to the provider, bypassing Bifrost."
announce "EXPECTED: each of the three models returns a completion (HTTP 200)."
announce "This script intentionally targets api.openai.com. It is the only script that does."

load_env

# Strip the Bifrost "openai/" prefix for a direct provider call.
strip_prefix() { printf '%s' "${1#openai/}"; }

preflight_one() {
  local tier="$1" model_ref="$2"
  local model; model="$(strip_prefix "$model_ref")"
  local body
  body=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' "$model" "$PROMPT")

  announce "PREFLIGHT [$tier]: model=$model (direct)"
  say_masked "  POST $PROVIDER_URL"
  say_masked "  Authorization: Bearer \$OPENAI_API_KEY   (masked; never printed)"
  say_masked "  body: $body"

  if is_dry_run; then
    announce "  DRY_RUN: no network call made."
    return 0
  fi

  require_env OPENAI_API_KEY

  # -i captures headers; -w captures the final HTTP status. No retries.
  local resp status
  resp=$(curl -sS -i -X POST "$PROVIDER_URL" \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    -w '\n__HTTP_STATUS__:%{http_code}\n' \
    -d "$body" 2>&1)
  status=$(printf '%s' "$resp" | sed -n 's/^__HTTP_STATUS__://p' | tr -d '\r')
  [ -z "$status" ] && status="NO_RESPONSE"

  # Append verbatim, secrets masked. Role is n/a for a direct provider call.
  log_append "n/a(direct)" "$model" "$status" "$(printf '%s' "$resp" | mask_secrets)"
  announce "  logged. HTTP status: $status"
}

log_section "PREFLIGHT - direct provider calls, bypassing Bifrost (Block 0)"

preflight_one "routine"    "${MODEL_ROUTINE:-openai/UNSET}"
preflight_one "standard"   "${MODEL_STANDARD:-openai/UNSET}"
preflight_one "restricted" "${MODEL_RESTRICTED:-openai/UNSET}"

announce "Pre-flight done. Read the PREFLIGHT section of raw_output.log for verbatim responses."
exit 0
