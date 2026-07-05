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

# --- in-flight worker defer (background-worker awareness) -------------------
# If the master BACKGROUNDED a worker and is now yielding the turn to await it,
# this is NOT "quitting": a worker is still churning, so the scoreboard would be a
# torn read and pushing "spawn a fresh worker" would double-dispatch onto the same
# files. Defer instead — allow the yield so the master rests until the worker's
# completion notification re-invokes it; do NOT count it against hook_blocks. Each
# marker carries a TTL, so a crashed worker whose end was never recorded self-heals
# (the marker expires and the gate resumes blocking). Off with GDCC_INFLIGHT_GATE=0;
# inert (no markers) for the pure synchronous loop, so it changes nothing there.
if [ "${GDCC_INFLIGHT_GATE:-1}" != "0" ]; then
  live="$(gd_workers_live "$DIR" 2>/dev/null || true)"
  if [ -n "$live" ]; then
    echo "goal-driven gate: a worker is still in flight ($(printf '%s' "$live" | tr '\n' ' '))— deferring, not re-dispatching. The master should wait for its completion (or 'gdcc stop' to end)." >&2
    exit 0
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
  echo "The goal-driven criteria (the Judge) have NOT passed yet — do not stop; keep working (or escalate the RIGHT way, below)."
  echo
  echo "JUDGE SCOREBOARD (non-zero exit = goal not reached):"
  echo "$tail_out"
  echo
  echo "Normal case — keep working:"
  echo "1) Read the [FAIL] lines above — those are what's still failing, with reasons."
  echo "2) Spawn a fresh goal-worker targeting the specific failing checks (read GOAL.md + PROGRESS.md tail first)."
  echo "3) Re-run the Judge: bash .goal-driven/CRITERIA.sh ; append one line to PROGRESS.md. Do NOT edit CRITERIA.sh or the tests."
  echo
  echo "If you think a criterion is stuck/unreachable — do NOT decide that yourself, and do NOT stop or disarm:"
  echo "A) Spawn goal-decider (model fable) to CRITICALLY vet the claim. It must hunt for contradictions and holes —"
  echo "   e.g. weaker hardware/config outperforming this one, results that violate expected scaling, assumptions never"
  echo "   actually measured, untried decompositions/angles. Give it the facts + the exact 'unreachable' argument."
  echo "B) If goal-decider says RESUME → keep working on the angle it found (the claim was premature)."
  echo "C) ONLY if it CONFIRMS genuinely blocked → run:  gdcc escalate \"<the vetted analysis + the decision you need>\""
  echo "   That records ESCALATION.md and cleanly pauses for the human. Never escalate on your own judgment alone."
} >&2
exit 2
