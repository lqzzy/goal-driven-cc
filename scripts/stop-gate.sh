#!/usr/bin/env bash
# ============================================================================
# stop-gate.sh -- in-session negative-feedback gate (the deterministic floor).
#
# Wired as a Stop hook. When the master (the main agent) tries to end its turn,
# this READS the strict-verifier's cached verdict (verdict.json) — it never runs
# an LLM itself (that would re-enter this same hook and fork-bomb). If the task is
# ARMED and the verdict isn't fresh + all-pass + pass^k, it BLOCKS (exit 2) and
# feeds back exactly why. INERT unless the cwd tree has an armed .goal-driven task,
# so installing the plugin never disturbs normal sessions.
#
# Also enforces the seal checksum: if GOAL.md/CRITERIA.md were tampered with mid-run
# it blocks and demands they be restored (a worker must never edit its own goalposts).
# Fail-open: only the verdict decision blocks; internal errors never wedge you.
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
    echo "goal-driven gate: the sealed GOAL.md/CRITERIA.md has been modified during this run. The goalposts must never be edited to make the goal pass. Restore them from git (git checkout -- .goal-driven/GOAL.md .goal-driven/CRITERIA.md) and solve the goal for real." >&2
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

# --- verdict gate (reads the strict-verifier's cached verdict; never runs an LLM) ---
# The Judge is the strict-verifier, which runs OUTSIDE this hook and writes
# verdict.json. This gate only READS it: allow the stop iff the verdict is FRESH
# (its tree_hash still matches the working tree), ALL-PASS, and has reached the
# pass^k streak (GDCC_CONSECUTIVE_PASSES green verifications in a row). Anything
# else blocks with the precise reason. An LLM must NEVER run here -> fork bomb.
VF="$DIR/verdict.json"
cur="$(gd_tree_hash "$ROOT" 2>/dev/null)"
vt="$(gd_verdict_tree "$DIR")"
fresh=1; { [ -n "$cur" ] && [ "$cur" != "$vt" ]; } && fresh=0
if [ -f "$VF" ] && [ "$fresh" = 1 ] && gd_verdict_allpass "$DIR" && [ "$(gd_verdict_streak "$DIR")" -ge "$K" ]; then
  rm -f "$DIR/hook_blocks"; exit 0                                  # goal genuinely reached -> allow stop
fi

blocks="$(cat "$DIR/hook_blocks" 2>/dev/null || echo 0)"
[ "$blocks" -ge "$MAX" ] && exit 0                                  # runaway cap -> allow stop
echo $((blocks + 1)) > "$DIR/hook_blocks"

if [ ! -f "$VF" ]; then
  reason="No verdict yet — the criteria have never been verified this run."
  action="Spawn the strict-verifier subagent to judge CRITERIA.md against the artifacts (it writes verdict.txt, then runs 'gdcc verdict record')."
elif [ "$fresh" = 0 ]; then
  reason="The verdict is STALE — code changed since it was recorded (tree hash differs)."
  action="Re-run the strict-verifier on the CURRENT code before stopping."
elif ! gd_verdict_allpass "$DIR"; then
  reason="The verdict has failing criteria (see the scoreboard below)."
  action="Spawn a fresh goal-worker targeting the [FAIL] criteria (read GOAL.md + PROGRESS.md tail first), then re-verify."
else
  reason="Not enough consecutive green verifications yet (pass^k: need $K in a row, have $(gd_verdict_streak "$DIR"))."
  action="Re-run the strict-verifier to extend the streak."
fi
tail_out="$(tail -n 120 "$DIR/verdict.txt" 2>/dev/null)"
{
  echo "The goal-driven criteria have NOT been met yet — do not stop; keep working (or escalate the RIGHT way, below)."
  echo
  echo "WHY: $reason"
  echo "DO:  $action"
  echo
  echo "LATEST VERDICT (strict-verifier scoreboard):"
  echo "${tail_out:-(none recorded yet)}"
  echo
  echo "If you think a criterion is stuck/unreachable — do NOT decide that yourself, and do NOT stop or disarm:"
  echo "A) Spawn goal-decider (model fable) to CRITICALLY vet the claim — hunt for contradictions, untested assumptions, untried angles."
  echo "B) If goal-decider says RESUME → keep working on the angle it found (the claim was premature)."
  echo "C) ONLY if it CONFIRMS genuinely blocked → run:  gdcc escalate \"<the vetted analysis + the decision you need>\""
  echo "   That records ESCALATION.md and cleanly pauses for the human. Never escalate on your own judgment alone."
  echo
  echo "NEVER edit GOAL.md or CRITERIA.md to pass — the seal checksum catches it and halts the loop."
} >&2
exit 2
