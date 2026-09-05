#!/usr/bin/env bash
# 02-matrix.sh - Block 4 "the matrix".
#
# ONE JOB: nine calls, each role against each model, through the gateway.
# Declares the expected result of every call BEFORE running it, then records
# what actually came back. Comparison is deterministic: expected vs observed.
# No model interprets anything.
#
# Roles run narrowest to widest by FUNCTION, not seniority:
#   interpreter - narrowest (routine model only)
#   reporter    - middle    (routine + standard)
#   clerk       - widest    (all three; audits the case live)
#
# Expected table (tier labels name the ACCESS LEVEL, not the cost):
#   Role         routine   standard   restricted
#   interpreter  ALLOW     DENY       DENY
#   reporter     ALLOW     ALLOW      DENY
#   clerk        ALLOW     ALLOW      ALLOW
# Total: 6 ALLOW, 3 DENY.
#
# A DENY is an expected, successful observation. It is NOT a script failure.
# The script exits 0 whether calls are allowed or denied. It exits non-zero
# only if the harness itself broke.
#
# Role NAMES are printed and logged. Virtual-key VALUES come from .env and are
# never printed. Model names come ONLY from .env.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

load_env

GATEWAY_URL="${BIFROST_URL:-http://localhost:8090}/v1/chat/completions"
PROMPT='hello'

# Role names, in matrix order (narrowest to widest). Virtual-key values are
# looked up from .env by name.
ROLES=(interpreter reporter clerk)
# Map each role NAME to the .env variable holding its virtual-key VALUE.
role_var() {
  case "$1" in
    interpreter) printf 'VK_INTERPRETER' ;;
    reporter)    printf 'VK_REPORTER' ;;
    clerk)       printf 'VK_CLERK' ;;
  esac
}

# Tier order for the matrix (access level, not cost). This is an internal loop
# variable, deliberately NOT named MODEL_* so it does not collide with the config
# variables that must live in .env. The actual model names come from .env only.
TIER_ORDER=(routine standard restricted)
model_for_tier() {
  case "$1" in
    routine)    printf '%s' "${MODEL_ROUTINE:-openai/UNSET}" ;;
    standard)   printf '%s' "${MODEL_STANDARD:-openai/UNSET}" ;;
    restricted) printf '%s' "${MODEL_RESTRICTED:-openai/UNSET}" ;;
  esac
}

# Expected outcome per role+tier. This is the declared truth the run is checked
# against. ALLOW or DENY.
expected_for() {
  # usage: expected_for <role> <tier>
  case "$1:$2" in
    interpreter:routine)    printf 'ALLOW' ;;
    interpreter:standard)   printf 'DENY'  ;;
    interpreter:restricted) printf 'DENY'  ;;
    reporter:routine)       printf 'ALLOW' ;;
    reporter:standard)      printf 'ALLOW' ;;
    reporter:restricted)    printf 'DENY'  ;;
    clerk:routine)          printf 'ALLOW' ;;
    clerk:standard)         printf 'ALLOW' ;;
    clerk:restricted)       printf 'ALLOW' ;;
  esac
}

announce "Block 4: the permission matrix. Nine calls, each role against each model."
announce "EXPECTED (declared before the run):"
announce "  role         routine   standard   restricted"
announce "  interpreter  ALLOW     DENY       DENY"
announce "  reporter     ALLOW     ALLOW      DENY"
announce "  clerk        ALLOW     ALLOW      ALLOW"
announce "  total: 6 ALLOW, 3 DENY"
announce "A DENY is an expected observation, not a failure. Exit code stays 0 either way."

# --- run one cell ----------------------------------------------------------

run_cell() {
  local role="$1" tier="$2"
  local model; model="$(model_for_tier "$tier")"
  local expected; expected="$(expected_for "$role" "$tier")"
  local var; var="$(role_var "$role")"

  local body
  body=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' "$model" "$PROMPT")

  announce ""
  announce "CALL: role=$role  model=$model  tier=$tier  EXPECTED=$expected"
  say_masked "  POST $GATEWAY_URL"
  say_masked "  x-bf-vk: \$$var   (virtual-key value masked; role is '$role')"
  say_masked "  body: $body"

  if is_dry_run; then
    announce "  DRY_RUN: no network call made."
    return 0
  fi

  require_env "$var"
  local vk_value="${!var}"

  local resp status
  resp=$(curl -sS -i -X POST "$GATEWAY_URL" \
    -H "x-bf-vk: ${vk_value}" \
    -H "Content-Type: application/json" \
    -w '\n__HTTP_STATUS__:%{http_code}\n' \
    -d "$body" 2>&1)
  status=$(printf '%s' "$resp" | sed -n 's/^__HTTP_STATUS__://p' | tr -d '\r')
  [ -z "$status" ] && status="NO_RESPONSE"

  # Record verbatim (masked), with expected outcome noted for later comparison.
  log_append "$role" "$model" "$status" \
    "EXPECTED=$expected"$'\n'"$(printf '%s' "$resp" | mask_secrets)"
  announce "  logged. EXPECTED=$expected  HTTP status: $status"
}

log_section "BLOCK 4 - the permission matrix, nine calls through the gateway"

for role in "${ROLES[@]}"; do
  for tier in "${TIER_ORDER[@]}"; do
    run_cell "$role" "$tier"
  done
done

announce ""
announce "Matrix done. Nine calls attempted. Read BLOCK 4 in raw_output.log for verbatim responses."
announce "Compare EXPECTED vs the HTTP status of each entry by hand for RUN_REPORT.md."
exit 0
