#!/usr/bin/env bash
# 02b-provenance.sh - Block 4b "prove the traffic went through Bifrost".
#
# ONE JOB: record the evidence that the matrix calls passed through the gateway
# rather than going straight to the provider. Five pieces, cheapest first.
#
# IMPORTANT: this script does NOT stop or start Docker. The negative control is
# Shara's to run by hand so she can say in the article that she killed the
# container and watched the call fail. This script prints the exact commands and
# waits. It runs the "before" call (should succeed) and records it; the human
# runs the "after container stopped" call.
#
# Model name comes ONLY from .env. Role names printed, virtual-key values never.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

load_env

GATEWAY_URL="${BIFROST_URL:-http://localhost:8090}/v1/chat/completions"
HEALTH_URL="${BIFROST_URL:-http://localhost:8090}/health"
MODEL="${MODEL_ROUTINE:-openai/UNSET}"
PROMPT='hello'
# Provenance uses the clerk role (widest) on the routine model: a call that is
# EXPECTED to succeed, so the negative control has a clean "before" to fail against.
ROLE_NAME="clerk"
ROLE_VAR="VK_CLERK"

body=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' "$MODEL" "$PROMPT")

announce "Block 4b: provenance. How we know the traffic went through Bifrost."
announce "EXPECTED: gateway-stamped headers on a live call; a virtual-key credential alone cannot reach OpenAI;"
announce "          and (Shara runs this) the same call fails with connection refused when the"
announce "          container is stopped."

# --- 1 & 2: address and credential asymmetry (always printable) ------------
announce ""
announce "1. THE ADDRESS: every gateway call targets exactly this URL:"
say_masked "   $GATEWAY_URL"
announce "2. THE CREDENTIAL: the client holds only a Bifrost virtual-key credential. That value"
announce "   cannot authenticate to OpenAI. If a call carrying only it returns a"
announce "   completion, something upstream (Bifrost) substituted the real key."
announce "   No OPENAI_API_KEY is sent on any gateway call from these scripts."

if is_dry_run; then
  announce ""
  announce "3. RESPONSE HEADERS: (live) captured with curl -i on the call below."
  say_masked "   POST $GATEWAY_URL   x-bf-vk: \$$ROLE_VAR   (role '$ROLE_NAME')"
  announce "4. DENIAL VOCABULARY: (live) quote any denial text mentioning 'virtual key'"
  announce "   or 'budget' from Block 4 - a provider never uses those words."
  announce "5. NEGATIVE CONTROL: printed for Shara to run by hand (see below)."
  announce ""
  announce "ENV FACTS that would be recorded live: docker ps, image digest, date -u, /health."
  announce ""
  announce ">>> NEGATIVE CONTROL, to be run BY HAND during the live run:"
  announce "    a) docker stop <container>       # Shara kills the container"
  announce "    b) rerun the exact successful call from Block 4 -> EXPECT connection refused"
  announce "    c) docker start <container>      # restart"
  announce "    d) rerun once more               -> EXPECT success again"
  announce "  DRY_RUN: no network call made."
  exit 0
fi

log_section "BLOCK 4b - provenance evidence"

# --- Environment facts ---
announce ""
announce "Recording environment facts (docker ps, image digest, date -u, /health)."
{
  printf '\n--- ENV FACTS ---\n'
  printf '# date -u\n'; date -u
  printf '\n# docker ps\n'; docker ps 2>&1
  printf '\n# docker images --digests maximhq/bifrost\n'; docker images --digests maximhq/bifrost 2>&1
  printf '\n# GET %s\n' "$HEALTH_URL"; curl -sS -i "$HEALTH_URL" 2>&1 | mask_secrets
  printf '\n'
} >> "$LOG_FILE"

# --- 3: response headers on a live, expected-to-succeed call ---
announce ""
announce "3. RESPONSE HEADERS: making one live call (role=$ROLE_NAME, model=$MODEL) to capture all headers."
require_env "$ROLE_VAR"
vk_value="${!ROLE_VAR}"

resp=$(curl -sS -i -X POST "$GATEWAY_URL" \
  -H "x-bf-vk: ${vk_value}" \
  -H "Content-Type: application/json" \
  -w '\n__HTTP_STATUS__:%{http_code}\n' \
  -d "$body" 2>&1)
status=$(printf '%s' "$resp" | sed -n 's/^__HTTP_STATUS__://p' | tr -d '\r')
[ -z "$status" ] && status="NO_RESPONSE"
log_append "$ROLE_NAME" "$MODEL" "$status" \
  "PROVENANCE 'before' call (should succeed). Full headers below."$'\n'"$(printf '%s' "$resp" | mask_secrets)"
announce "  logged headers verbatim. HTTP status: $status"

# --- 4: denial vocabulary ---
announce ""
announce "4. DENIAL VOCABULARY: from Block 4's denials in raw_output.log, quote any text"
announce "   that references 'virtual key' or 'budget'. A provider never uses those words,"
announce "   so that language could only have come from the gateway. (Recorded by hand in RUN_REPORT.md.)"

# --- 5: negative control, HUMAN-RUN ---
announce ""
announce ">>> 5. NEGATIVE CONTROL - THIS PART IS YOURS TO RUN, SHARA. The script will not"
announce "    touch Docker. Run these yourself so you can say you watched it fail:"
announce ""
announce "    a) Stop the container:   docker stop <container-name-or-id>"
announce "    b) Rerun the same call (EXPECT: connection refused):"
say_masked "         curl -sS -i -X POST $GATEWAY_URL -H 'x-bf-vk: <clerk virtual key from .env>' -H 'Content-Type: application/json' -d '$body'"
announce "    c) Restart the container: docker start <container-name-or-id>"
announce "    d) Rerun once more (EXPECT: success again)."
announce ""
announce "    Paste both verbatim outputs into raw_output.log under a NEGATIVE CONTROL heading."
announce "    If step (b) does NOT fail, STOP. Something else answered and every result is suspect."
{
  printf '\n--- NEGATIVE CONTROL (human-run) ---\n'
  printf '# Shara runs the stop/call/start/call sequence by hand and pastes verbatim output here.\n'
  printf '# EXPECT: connection refused while stopped; success again after restart.\n\n'
} >> "$LOG_FILE"

announce ""
announce "Provenance recording done (env facts + live headers). Negative control awaits your hand-run."
exit 0
