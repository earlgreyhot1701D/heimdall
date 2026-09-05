#!/usr/bin/env bash
# 03-budget-trip.sh - Block 5 "running out of money".
#
# ONE JOB: loop calls on the interpreter role against its ALLOWED (routine) model
# until the $0.05 budget is exhausted, and capture the exact moment it trips.
# interpreter is the narrowest role and carries the tiny $0.05 budget, so it is
# the one built to be exhausted.
#
# The interpreter is allowed the routine model, so early calls should SUCCEED. The
# finding is what happens when the budget runs out: the HTTP status, the
# verbatim response, and whether the failure is clean or ambiguous.
#
# Budget exhaustion is an EXPECTED observation, not a script failure. The script
# exits 0. It exits non-zero only if the harness itself broke.
#
# A hard cap on iterations stops a runaway loop from burning money if the budget
# never trips (which would itself be a finding). No retries within a call.
#
# Model name from .env only. Role name printed, virtual-key value never.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

load_env

GATEWAY_URL="${BIFROST_URL:-http://localhost:8090}/v1/chat/completions"
MODEL="${MODEL_ROUTINE:-openai/UNSET}"
PROMPT='hello'
ROLE_NAME="interpreter"
ROLE_VAR="VK_INTERPRETER"

# Safety cap. The interpreter budget is $0.05 and each "hello" is a fraction of a
# cent, so this should trip well before the cap. If it does not, the cap protects
# the provider-side spend limit and the non-trip is recorded as the finding.
MAX_CALLS="${MAX_CALLS:-200}"

body=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' "$MODEL" "$PROMPT")

announce "Block 5: budget exhaustion on the interpreter role (its allowed routine model)."
announce "EXPECTED: calls succeed until the \$0.05 budget is reached, then fail with a"
announce "          message that names the budget as the reason."
announce "Safety cap: at most $MAX_CALLS calls, in case the budget never trips (a finding in itself)."
say_masked "  POST $GATEWAY_URL   x-bf-vk: \$$ROLE_VAR   (role '$ROLE_NAME')"
say_masked "  body: $body"

if is_dry_run; then
  announce "  DRY_RUN: no network call made. (Live run loops up to $MAX_CALLS times.)"
  exit 0
fi

require_env "$ROLE_VAR"
vk_value="${!ROLE_VAR}"

log_section "BLOCK 5 - budget exhaustion loop on the interpreter role"

i=0
tripped=0
while [ "$i" -lt "$MAX_CALLS" ]; do
  i=$((i + 1))
  resp=$(curl -sS -i -X POST "$GATEWAY_URL" \
    -H "x-bf-vk: ${vk_value}" \
    -H "Content-Type: application/json" \
    -w '\n__HTTP_STATUS__:%{http_code}\n' \
    -d "$body" 2>&1)
  status=$(printf '%s' "$resp" | sed -n 's/^__HTTP_STATUS__://p' | tr -d '\r')
  [ -z "$status" ] && status="NO_RESPONSE"

  log_append "$ROLE_NAME" "$MODEL" "$status" \
    "budget-loop call #$i"$'\n'"$(printf '%s' "$resp" | mask_secrets)"
  announce "  call #$i -> HTTP $status"

  # A non-2xx after prior successes is very likely the budget tripping. Record
  # it and stop the loop. We do not interpret WHY here beyond stopping; the
  # verbatim body in the log is the evidence read into RUN_REPORT.md.
  case "$status" in
    2*) : ;;  # success, keep going
    NO_RESPONSE)
      announce "  no response - stopping loop (harness/network issue, recorded verbatim)."
      break
      ;;
    *)
      announce "  non-2xx at call #$i. Treating as the trip point. Stopping loop."
      tripped=1
      break
      ;;
  esac
done

if [ "$tripped" -eq 1 ]; then
  announce "Budget appears to have tripped at call #$i. Read BLOCK 5 in raw_output.log for the verbatim response."
else
  announce "Loop ended after $i calls without a clear non-2xx trip. That non-trip is itself the finding - record it."
fi
exit 0
