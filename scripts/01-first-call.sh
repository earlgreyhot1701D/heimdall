#!/usr/bin/env bash
# 01-first-call.sh - Block 1 "the door opens".
#
# ONE JOB: one UNAUTHENTICATED call to the gateway at $BIFROST_URL.
# No virtual key, no key. Just proves the gateway is up and answering.
# Shara runs this by hand during the live run.
#
# Model name comes ONLY from .env (MODEL_ROUTINE). Never hardcoded.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

load_env

# BIFROST_URL from .env is the source of truth for the address. The fallback
# below matches .env.example so no literal disagrees with the configured port.
GATEWAY_URL="${BIFROST_URL:-http://localhost:8090}/v1/chat/completions"
MODEL="${MODEL_ROUTINE:-openai/UNSET}"
PROMPT='hello'

body=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' "$MODEL" "$PROMPT")

announce "Block 1: one UNAUTHENTICATED call to the gateway."
announce "EXPECTED: the gateway answers (a response comes back through \$BIFROST_URL)."
say_masked "  POST $GATEWAY_URL"
say_masked "  (no x-bf-vk header - this call carries no virtual key)"
say_masked "  body: $body"

if is_dry_run; then
  announce "  DRY_RUN: no network call made."
  exit 0
fi

log_section "BLOCK 1 - first call, unauthenticated, through the gateway"

# -i captures all response headers (provenance). No retries.
resp=$(curl -sS -i -X POST "$GATEWAY_URL" \
  -H "Content-Type: application/json" \
  -w '\n__HTTP_STATUS__:%{http_code}\n' \
  -d "$body" 2>&1)
status=$(printf '%s' "$resp" | sed -n 's/^__HTTP_STATUS__://p' | tr -d '\r')
[ -z "$status" ] && status="NO_RESPONSE"

log_append "none(unauth)" "$MODEL" "$status" "$(printf '%s' "$resp" | mask_secrets)"
announce "  logged. HTTP status: $status"
exit 0
