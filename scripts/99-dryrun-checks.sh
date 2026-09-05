#!/usr/bin/env bash
# 99-dryrun-checks.sh - the Phase A gate.
#
# ONE JOB: run the eight dry-run self-checks from the PRD and print a plain-
# English PASS or FAIL for each. This is the harness testing itself before any
# key or Docker exists.
#
# Runs with NO .env present. Phase A happens before a key exists, so this
# validates against .env.example ONLY. If it needed a real .env, the gate would
# be in the wrong phase.
#
# This script never truncates raw_output.log, never creates or edits .gitignore,
# and makes no network call. It only reads and reports.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

BLOCK_SCRIPTS=("$DIR/00-preflight.sh" "$DIR/01-first-call.sh" "$DIR/02-matrix.sh" "$DIR/02b-provenance.sh" "$DIR/03-budget-trip.sh")
# Gateway scripts: these must NEVER target a provider domain. 00-preflight is
# the explicit, by-design exception and is excluded from the localhost check.
GATEWAY_SCRIPTS=("$DIR/01-first-call.sh" "$DIR/02-matrix.sh" "$DIR/02b-provenance.sh" "$DIR/03-budget-trip.sh")

PASS_COUNT=0
FAIL_COUNT=0

report() {
  # usage: report <PASS|FAIL> <n> <title> <detail>
  local result="$1" n="$2" title="$3" detail="$4"
  printf 'CHECK %s: %-42s [%s]\n' "$n" "$title" "$result"
  [ -n "$detail" ] && printf '         %s\n' "$detail"
  if [ "$result" = "PASS" ]; then PASS_COUNT=$((PASS_COUNT+1)); else FAIL_COUNT=$((FAIL_COUNT+1)); fi
}

printf '========================================================\n'
printf 'HEIMDALL - Phase A dry-run self-checks\n'
printf 'No keys. No Docker. No network. Validates against .env.example.\n'
printf '========================================================\n\n'

# --- CHECK 1: exactly 9 role-model combinations ------------------------------
# Run the matrix in dry run and count the "CALL:" announcements.
matrix_out="$(DRY_RUN=1 ENV_FILE=/nonexistent bash "$DIR/02-matrix.sh" 2>&1)"
cell_count="$(printf '%s\n' "$matrix_out" | grep -c '^--- CALL: role=')"
if [ "$cell_count" -eq 9 ]; then
  report PASS 1 "Exactly 9 role-model combinations" "matrix generated $cell_count calls"
else
  report FAIL 1 "Exactly 9 role-model combinations" "matrix generated $cell_count calls, expected 9"
fi

# --- CHECK 2: expected table sums to 6 ALLOW, 3 DENY -------------------------
allow_count="$(printf '%s\n' "$matrix_out" | grep -o 'EXPECTED=ALLOW' | wc -l | tr -d ' ')"
deny_count="$(printf '%s\n' "$matrix_out" | grep -o 'EXPECTED=DENY' | wc -l | tr -d ' ')"
if [ "$allow_count" -eq 6 ] && [ "$deny_count" -eq 3 ]; then
  report PASS 2 "Expected table sums to 6 ALLOW, 3 DENY" "found $allow_count ALLOW, $deny_count DENY"
else
  report FAIL 2 "Expected table sums to 6 ALLOW, 3 DENY" "found $allow_count ALLOW, $deny_count DENY"
fi

# --- CHECK 3: every referenced variable exists in .env.example ---------------
# Discover the harness's config variables by PATTERN, not a hardcoded list, so a
# rename (MODEL_CHEAP -> MODEL_ROUTINE, VK_MANAGER -> VK_CLERK, etc.) cannot make
# this check silently miss a variable. We match the naming families the harness
# uses: MODEL_*, VK_*, plus the two fixed names OPENAI_API_KEY and BIFROST_URL.
# Matched wherever they appear - as $VAR / ${VAR} expansions AND as bare names
# inside case/printf (role_var maps role names to VK_* strings).
referenced_vars=$(grep -rhoE '\b(MODEL_[A-Z]+|VK_[A-Z]+|OPENAI_API_KEY|BIFROST_URL)\b' "${BLOCK_SCRIPTS[@]}" \
  | sort -u)
missing_vars=""
for v in $referenced_vars; do
  if ! grep -qE "^[[:space:]]*${v}=" "$ENV_EXAMPLE"; then
    missing_vars="$missing_vars $v"
  fi
done
if [ -z "$missing_vars" ]; then
  report PASS 3 "Every referenced var is in .env.example" "checked: $(printf '%s' "$referenced_vars" | tr '\n' ' ')"
else
  report FAIL 3 "Every referenced var is in .env.example" "missing:$missing_vars"
fi

# --- CHECK 4: no model name hardcoded outside .env ---------------------------
# Model names live only in .env / .env.example (and config.json, which is
# Bifrost's allowlist, not a script). A script must not contain a literal model
# id. We look for the tell-tale "openai/gpt" or bare "gpt-" model strings in the
# block scripts. Allowed: the placeholder "openai/UNSET" fallback markers.
hardcoded=""
for s in "${BLOCK_SCRIPTS[@]}"; do
  hits="$(grep -nE 'gpt-[0-9]' "$s" || true)"
  if [ -n "$hits" ]; then
    hardcoded="$hardcoded\n$s:\n$hits"
  fi
done
if [ -z "$hardcoded" ]; then
  report PASS 4 "No model name hardcoded in any script" "scripts reference MODEL_* from .env only (config.json is Bifrost allowlist, exempt)"
else
  report FAIL 4 "No model name hardcoded in any script" "$(printf '%b' "$hardcoded")"
fi

# --- CHECK 5: no sk- value in any printed dry-run output ---------------------
# Run every script in dry run and confirm no unmasked sk- token appears. Since
# no .env exists, no real value could leak anyway, but we assert masking works:
# any sk- must be the masked form sk-***MASKED*** or a placeholder from example.
leak=""
for s in "${BLOCK_SCRIPTS[@]}"; do
  out="$(DRY_RUN=1 ENV_FILE=/nonexistent bash "$s" 2>&1)"
  # Find sk- tokens that are NOT the masked marker.
  bad="$(printf '%s\n' "$out" | grep -oE 'sk-[A-Za-z0-9_-]+' | grep -v '^sk-\*\*\*MASKED\*\*\*$' || true)"
  if [ -n "$bad" ]; then
    leak="$leak\n$(basename "$s"): $bad"
  fi
done
if [ -z "$leak" ]; then
  report PASS 5 "No sk- value printed in any dry run" "all sk- tokens masked or absent"
else
  report FAIL 5 "No sk- value printed in any dry run" "$(printf '%b' "$leak")"
fi

# --- CHECK 6: every gateway request targets BIFROST_URL, never a provider -----
# The gateway address is NOT hardcoded here. We read BIFROST_URL from
# .env.example (Phase A has no .env) so this check follows the real address
# wherever it is set. Same drift lesson as badge= and the tier rename: a check
# keyed to a literal "localhost:8080" would silently pass while pointing at the
# wrong port. This one moves with the config.
#
# Two assertions:
#   a) No gateway script contains a provider domain. 00-preflight is the one
#      documented exception (it MUST hit api.openai.com), shown, not hidden.
#   b) Every gateway script routes through $BIFROST_URL, and does not hardcode a
#      gateway host:port that DIFFERS from BIFROST_URL (a divergent literal is
#      exactly the drift we are guarding against). A :-fallback equal to the
#      generic Bifrost default is allowed; a fallback that disagrees is a FAIL.
BIFROST_URL_EXPECTED="$(grep -E '^[[:space:]]*BIFROST_URL=' "$ENV_EXAMPLE" | head -n1 | cut -d= -f2- | tr -d '[:space:]')"
EXPECTED_HOSTPORT="$(printf '%s' "$BIFROST_URL_EXPECTED" | sed -E 's#^https?://##')"

provider_in_gateway=""
missing_var_ref=""
divergent_literal=""
for s in "${GATEWAY_SCRIPTS[@]}"; do
  hits="$(grep -nE 'api\.openai\.com|api\.anthropic\.com|googleapis\.com' "$s" || true)"
  if [ -n "$hits" ]; then
    provider_in_gateway="$provider_in_gateway\n$(basename "$s"): $hits"
  fi
  # (b) must reference $BIFROST_URL
  if ! grep -qE 'BIFROST_URL' "$s"; then
    missing_var_ref="$missing_var_ref $(basename "$s")"
  fi
  # any localhost:PORT literal whose host:port differs from BIFROST_URL is drift
  for lit in $(grep -oE 'localhost:[0-9]+' "$s" | sort -u); do
    if [ "$lit" != "$EXPECTED_HOSTPORT" ]; then
      divergent_literal="$divergent_literal\n$(basename "$s"): $lit (expected $EXPECTED_HOSTPORT)"
    fi
  done
done

if [ -z "$provider_in_gateway" ] && [ -z "$missing_var_ref" ] && [ -z "$divergent_literal" ]; then
  report PASS 6 "Gateway scripts route through BIFROST_URL ($EXPECTED_HOSTPORT)" "no provider domain in gateway scripts; all route via \$BIFROST_URL; no divergent host:port literal. EXCEPTION shown: 00-preflight.sh targets api.openai.com by design."
else
  detail=""
  [ -n "$provider_in_gateway" ] && detail="$detail provider-domain:$(printf '%b' "$provider_in_gateway")"
  [ -n "$missing_var_ref" ] && detail="$detail not-using-BIFROST_URL:$missing_var_ref"
  [ -n "$divergent_literal" ] && detail="$detail divergent-literal:$(printf '%b' "$divergent_literal")"
  report FAIL 6 "Gateway scripts route through BIFROST_URL ($EXPECTED_HOSTPORT)" "$detail"
fi

# --- CHECK 7: .gitignore contains .env ---------------------------------------
# Read-only. Never creates or edits .gitignore. Reports FAIL if missing/wrong.
GITIGNORE="$REPO_ROOT/.gitignore"
if [ ! -f "$GITIGNORE" ]; then
  report FAIL 7 ".gitignore contains .env" ".gitignore does not exist (not created here by design)"
elif grep -qE '^[[:space:]]*\.env[[:space:]]*$' "$GITIGNORE"; then
  report PASS 7 ".gitignore contains .env" ".env is ignored"
else
  report FAIL 7 ".gitignore contains .env" ".gitignore exists but has no bare '.env' line"
fi

# --- CHECK 8: raw_output.log is writable (append-only) -----------------------
# Confirms we can append. Never truncates. Creates the file only if absent.
if ensure_log_writable; then
  report PASS 8 "raw_output.log is writable (append-only)" "$LOG_FILE can be appended to; not truncated"
else
  report FAIL 8 "raw_output.log is writable (append-only)" "cannot append to $LOG_FILE"
fi

# --- Summary ------------------------------------------------------------------
printf '\n--------------------------------------------------------\n'
printf 'RESULT: %d PASS, %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PHASE A GATE: PASS. All eight checks passed. Safe to proceed to Phase B.\n'
else
  printf 'PHASE A GATE: FAIL. Fix the failing checks before Phase B.\n'
fi
printf '========================================================\n'

# Exit code reflects the GATE (harness self-test), which is legitimate: a failed
# self-check IS a harness problem. This is distinct from a denied API call.
[ "$FAIL_COUNT" -eq 0 ]
