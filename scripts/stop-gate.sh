#!/usr/bin/env bash
# ============================================================================
# stop-gate.sh -- in-session negative-feedback gate (the deterministic floor).
#
# Wired as a Stop hook. When the master (the main agent) tries to end its turn,
# this runs the criteria (the Judge). If the task is ARMED and the criteria have
# not passed GDCC_CONSECUTIVE_PASSES times, it BLOCKS (exit 2) and feeds the
# scoreboard back so the loop continues. INERT unless the cwd tree has an armed
# .goal-driven task, so installing the plugin never disturbs normal sessions.
#
# Also enforces the seal checksum: if CRITERIA.sh was tampered with mid-run, it
# blocks and demands the judge be restored (a worker must never edit its judge).
# Fail-open: only the criteria decision blocks; internal errors never wedge you.
# ============================================================================
set -uo pipefail
source "$(dirname "$0")/lib/common.sh" 2>/dev/null || exit 0

cat >/dev/null 2>&1 || true   # consume hook JSON on stdin (we key off files)

DIR="$(gd_find_task_dir "$PWD" 2>/dev/null || true)"
[ -n "$DIR" ] && [ -f "$DIR/ACTIVE" ] || exit 0   # not armed -> allow stop
[ -f "$DIR/STOP" ] && exit 0                        # user asked to stop -> allow

[ -f "$DIR/config.env" ] && { set -a; source "$DIR/config.env" 2>/dev/null; set +a; }
K="${GDCC_CONSECUTIVE_PASSES:-2}"
MAX="${GDCC_MAX_ITERS:-50}"
ROOT="$(dirname "$DIR")"
mkdir -p "$DIR/logs" 2>/dev/null

# --- seal tamper check ---
if [ -f "$DIR/CRITERIA.sealed" ]; then
  want="$(grep '^criteria_hash=' "$DIR/CRITERIA.sealed" 2>/dev/null | cut -d= -f2-)"
  if [ -n "$want" ] && [ "$(gd_criteria_hash "$DIR")" != "$want" ]; then
    echo "goal-driven gate: the sealed CRITERIA.sh has been modified during this run. The judge must never be edited to make the goal pass. Restore .goal-driven/CRITERIA.sh from git (git checkout -- .goal-driven/CRITERIA.sh) and solve the goal for real." >&2
    exit 2
  fi
fi

# --- JUDGE, pass^k ---
allpass=1
for _ in $(seq 1 "$K"); do
  ( cd "$ROOT" && bash "$DIR/CRITERIA.sh" ) > "$DIR/logs/criteria-latest.log" 2>&1 || { allpass=0; break; }
done
if [ "$allpass" = 1 ]; then rm -f "$DIR/hook_blocks"; exit 0; fi   # goal reached -> allow stop

blocks="$(cat "$DIR/hook_blocks" 2>/dev/null || echo 0)"
[ "$blocks" -ge "$MAX" ] && exit 0                                  # runaway cap -> allow stop
echo $((blocks + 1)) > "$DIR/hook_blocks"

tail_out="$(tail -n 120 "$DIR/logs/criteria-latest.log" 2>/dev/null)"
{
  echo "The goal-driven criteria (the Judge) have NOT passed yet — this loop must continue, do not stop."
  echo
  echo "JUDGE SCOREBOARD (non-zero exit = goal not reached):"
  echo "$tail_out"
  echo
  echo "Do this now:"
  echo "1) Read the [x] lines above — those are what is still failing, with reasons."
  echo "2) Spawn a fresh goal-worker (or fix directly) targeting the specific failing checks. Read .goal-driven/GOAL.md and the tail of PROGRESS.md first."
  echo "3) Re-run the Judge: bash .goal-driven/CRITERIA.sh"
  echo "4) Append one line to .goal-driven/PROGRESS.md (what changed, what's next). Do NOT edit CRITERIA.sh or the tests."
} >&2
exit 2
