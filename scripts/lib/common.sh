#!/usr/bin/env bash
# Shared helpers for the goal-driven plugin (sourced by gdcc / gd-audit /
# judge / stop-gate / guard). Do not execute directly.

GD_STATE_DIRNAME=".goal-driven"

# Walk up from a directory to find the nearest .goal-driven/ task dir.
gd_find_task_dir() {
  local d="${1:-$PWD}"
  d="$(cd "$d" 2>/dev/null && pwd)" || return 1
  while :; do
    if [ -d "$d/$GD_STATE_DIRNAME" ]; then printf '%s\n' "$d/$GD_STATE_DIRNAME"; return 0; fi
    [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}

gd_now() { date '+%Y-%m-%dT%H:%M:%S'; }
gd_ts()  { date '+%H:%M:%S'; }
gd_log() { printf '[%s] %s\n' "$(gd_ts)" "$*"; }
gd_die() { printf 'gdcc: %s\n' "$*" >&2; exit 1; }

# Hash a file's contents: shasum, else cksum.
gd_hash_file() {
  if command -v shasum >/dev/null 2>&1; then shasum "$1" 2>/dev/null | awk '{print $1}'
  else cksum "$1" 2>/dev/null | awk '{print $1}'; fi
}

# Hash the sealed surface so tampering with the goal OR the criteria is detectable.
# Covers GOAL.md + CRITERIA.sh + anything the designer parks under .goal-driven/judge/.
# (The success bar — goal and judge — is frozen once sealed.)
gd_criteria_hash() {
  local dir="$1" acc
  acc="$(gd_hash_file "$dir/CRITERIA.sh") $(gd_hash_file "$dir/GOAL.md")"
  if [ -d "$dir/judge" ]; then
    acc="$acc $(find "$dir/judge" -type f -exec shasum {} + 2>/dev/null | awk '{print $1}' | sort | tr '\n' ' ')"
  fi
  printf '%s' "$acc" | (shasum 2>/dev/null || cksum) | awk '{print $1}'
}

# Git tree hash of the current working state (for no-progress detection).
# Empty string if not a git repo.
gd_tree_hash() {
  local root="$1"
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || { echo ""; return; }
  git -C "$root" add -A >/dev/null 2>&1
  git -C "$root" write-tree 2>/dev/null
}

# --- Quota (reads claude-hud's usage cache; best-effort) --------------------
# claude-hud fetches the Anthropic usage API and caches it here every ~5 min.
# We reuse that cache instead of re-authenticating. Missing cache => unknown.
gd_quota_cache() { printf '%s' "${GDCC_QUOTA_SOURCE:-$HOME/.claude/plugins/claude-hud/.usage-cache.json}"; }

gd_quota_field() {  # $1 = jq path e.g. .data.fiveHour
  local c; c="$(gd_quota_cache)"
  [ -f "$c" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -r "$1 // empty" "$c" 2>/dev/null
}

# ISO8601 (e.g. 2026-07-02T10:00:00.192Z, UTC) -> epoch seconds.
gd_iso_to_epoch() {
  local s="${1%.*}"; s="${s%Z}"
  date -u -j -f "%Y-%m-%dT%H:%M:%S" "$s" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null
}

# Echo the 5-hour utilization percent (integer), or nothing if unknown.
gd_quota_pct5() { gd_quota_field '.data.fiveHour'; }
# Minutes until the 5-hour window resets, or nothing if unknown.
gd_quota_reset_min() {
  local iso re now; iso="$(gd_quota_field '.data.fiveHourResetAt')"; [ -n "$iso" ] || return 1
  re="$(gd_iso_to_epoch "$iso")"; [ -n "$re" ] || return 1
  now="$(date +%s)"; printf '%s' "$(( (re - now) / 60 ))"
}

# Portable timeout: gd_timeout <seconds> <cmd...>; 0/empty => no limit.
# The watcher's fds are redirected to /dev/null so a lingering `sleep` can never
# hold open a parent command-substitution pipe ( dout="$(gd_timeout ...)" ).
gd_timeout() {
  local secs="$1"; shift
  if [ -z "$secs" ] || [ "$secs" = "0" ]; then "$@"; return $?; fi
  "$@" &
  local cmd_pid=$!
  local watcher
  { sleep "$secs"; kill -TERM "$cmd_pid" 2>/dev/null; sleep 5; kill -KILL "$cmd_pid" 2>/dev/null; } >/dev/null 2>&1 &
  watcher=$!
  local rc=0
  wait "$cmd_pid" 2>/dev/null || rc=$?
  kill "$watcher" 2>/dev/null
  { kill "$(pgrep -P "$watcher" 2>/dev/null)" 2>/dev/null; } >/dev/null 2>&1 || true
  return "$rc"
}
