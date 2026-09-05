#!/usr/bin/env bash
# lib.sh - shared helpers for the Heimdall harness.
#
# One job: give the block scripts a common way to load config, mask secrets,
# echo intent, and append to raw_output.log. Nothing in here makes a decision
# about allow/deny. Nothing in here interprets a result.
#
# Rules enforced here so the block scripts cannot break them:
#   - raw_output.log is APPEND-ONLY. Every write uses >>. Never truncated.
#   - Virtual-key VALUES (sk-...) never printed. Role NAMES (clerk) always printed.
#   - DRY_RUN=1 prints the exact request and executes no network call.
#   - A denied call is data, not a failure. We never exit non-zero for a 403.

set -u  # undefined variable is a harness bug, surface it. (No -e: a curl
        # returning an HTTP error is expected data, not a script failure.)

# --- Paths -----------------------------------------------------------------

# Resolve the repo root from this file's location so scripts work from anywhere.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LIB_DIR/.." && pwd)"

ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"
ENV_EXAMPLE="$REPO_ROOT/.env.example"
LOG_FILE="${LOG_FILE:-$REPO_ROOT/raw_output.log}"

# --- Dry run ---------------------------------------------------------------

# DRY_RUN=1 means: print the request, mask secrets, touch no network, exit 0.
DRY_RUN="${DRY_RUN:-0}"

is_dry_run() { [ "$DRY_RUN" = "1" ]; }

# --- Secret masking --------------------------------------------------------

# Replace any token that starts with sk- (provider keys sk-... and virtual
# keys sk-bf-...) with a masked placeholder. Used on everything before it is
# printed or logged. The role NAME is passed separately and printed instead.
mask_secrets() {
  # Reads stdin, writes masked stdout.
  sed -E 's/sk-[A-Za-z0-9_-]+/sk-***MASKED***/g'
}

# Print a line to the terminal with any secret masked. Use this instead of a
# bare echo whenever the line could contain a key.
say_masked() {
  printf '%s\n' "$*" | mask_secrets
}

# --- Env loading -----------------------------------------------------------

# Load .env if it exists. In Phase A no .env exists and that is fine; the dry
# run validates against .env.example instead. Scripts that truly need a live
# key call require_env AFTER this and only outside dry run.
load_env() {
  if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set -a
    . "$ENV_FILE"
    set +a
  fi
}

# Fail the HARNESS (exit 2) only if a variable the script genuinely needs to
# make a live call is absent. Never called in dry run. This is a harness break,
# not a permission result.
require_env() {
  local name="$1"
  local val="${!name:-}"
  if [ -z "$val" ]; then
    printf 'HARNESS ERROR: required variable %s is not set. This is a harness break, not a test result.\n' "$name" >&2
    exit 2
  fi
}

# --- Logging (append-only) -------------------------------------------------

# Confirm the log can be appended to. Never truncates. Creates the file only if
# it does not exist. Returns non-zero if the log is unwritable (a harness break).
ensure_log_writable() {
  if [ -e "$LOG_FILE" ]; then
    [ -w "$LOG_FILE" ]
  else
    # File does not exist yet: can we create it? Test by appending nothing.
    ( : >> "$LOG_FILE" ) 2>/dev/null
  fi
}

now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# Append a raw block to the log with a header line carrying timestamp, role
# NAME, model, and HTTP status. The body is passed masked already by the caller
# for anything that could contain a key. APPEND ONLY.
#
# In DRY_RUN the log is never touched. Dry run mutates no state, and the log is
# evidence: a self-check must not be able to write a single line into it.
log_append() {
  # usage: log_append <role_name> <model> <http_status> <body...>
  is_dry_run && return 0
  local role="$1"; shift
  local model="$1"; shift
  local status="$1"; shift
  {
    printf '=== %s | role=%s | model=%s | http=%s\n' "$(now_utc)" "$role" "$model" "$status"
    printf '%s\n' "$*"
    printf '\n'
  } >> "$LOG_FILE"
}

# Append a free-form section (heading, env facts, notes) verbatim. APPEND ONLY.
# No-op under DRY_RUN for the same reason as log_append.
log_section() {
  is_dry_run && return 0
  {
    printf '===== %s | %s\n' "$(now_utc)" "$*"
  } >> "$LOG_FILE"
}

# --- Intent echo -----------------------------------------------------------

# Every script announces what it is about to do and what it expects, before it
# does it. This prints to the terminal, not the log.
announce() {
  printf -- '--- %s\n' "$*"
}
