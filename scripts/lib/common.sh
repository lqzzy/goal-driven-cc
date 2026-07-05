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

# --- In-flight worker registry (background-worker awareness for the Stop gate) ---
# When the master BACKGROUNDS a worker subagent and then yields the turn to await
# it, the Stop gate must tell "a worker is churning, just wait" apart from "nothing
# is running, quit". It can't share memory with the master/worker, so the signal
# lives on disk: each in-flight worker = one file under .goal-driven/workers/<id>.
# Liveness is bounded by an expiry (TTL) written into the marker — a subagent has
# no OS pid the hook could probe, so if `worker end` is never recorded (e.g. the
# worker crashed and the master was never re-invoked) the marker simply expires and
# the gate resumes normal blocking. Inert (dir absent) for the synchronous loop.
gd_workers_dir() { printf '%s\n' "$1/workers"; }

# gd_worker_begin <task_dir> <id> <ttl_secs> [label] -- mark a worker in-flight.
gd_worker_begin() {
  local dir="$1" id="${2:-main}" ttl="${3:-1800}" label="${4:-}" now exp wdir
  case "$ttl" in ''|*[!0-9]*) ttl=1800;; esac
  now="$(date +%s)"; exp=$(( now + ttl ))
  wdir="$(gd_workers_dir "$dir")"; mkdir -p "$wdir" 2>/dev/null || return 1
  { echo "id=$id"; echo "label=$label"; echo "started=$now"; echo "expires=$exp"; } > "$wdir/$id"
}

# gd_worker_end <task_dir> <id> -- record a worker as returned.
gd_worker_end() { rm -f "$(gd_workers_dir "$1")/${2:-main}" 2>/dev/null; }

# gd_workers_clear <task_dir> -- drop the whole registry (run ended / fresh arm).
gd_workers_clear() { rm -rf "$(gd_workers_dir "$1")" 2>/dev/null; }

# gd_workers_live <task_dir> -- print ids of live (non-expired) workers, one per
# line, reaping expired markers as a side effect. Return 0 if any live, else 1.
gd_workers_live() {
  local dir="$1" wdir now f exp id any=1
  wdir="$(gd_workers_dir "$dir")"
  [ -d "$wdir" ] || return 1
  now="$(date +%s)"
  for f in "$wdir"/*; do
    [ -e "$f" ] || continue
    exp="$(sed -n 's/^expires=//p' "$f" 2>/dev/null)"
    case "$exp" in ''|*[!0-9]*) exp=0;; esac
    if [ "$now" -lt "$exp" ]; then
      id="$(sed -n 's/^id=//p' "$f" 2>/dev/null)"
      printf '%s\n' "${id:-$(basename "$f")}"; any=0
    else
      rm -f "$f" 2>/dev/null   # expired / garbage -> reap
    fi
  done
  return "$any"
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
