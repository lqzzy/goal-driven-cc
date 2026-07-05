#!/usr/bin/env bash
# ============================================================================
# CRITERIA.sh -- the Judge (the sensor of the goal-driven control loop).
#
# CONTRACT (do not break):
#   * Exit 0  = the GOAL is fully met.
#   * Exit !=0 = not yet; the SCOREBOARD below shows WHICH criteria fail and why
#                (that text is fed back to the master/worker every iteration).
#   * Runs with the PROJECT ROOT as the working directory.
#   * Relocatable (project-relative paths only) so `gdcc audit` can run it in a copy.
#
# ── STRICTLY STATIC — a HARD invariant, not a preference ─────────────────────
# This script runs INSIDE the Stop hook on EVERY turn (and k times per pass^k).
# It MUST be deterministic, fast, and self-contained: only `check` with a plain
# command (tests / compile / grep / diff / a script). It MUST NOT call an LLM,
# spawn `claude`, hit the network, or launch anything that could re-enter a hook.
#   WHY: a `gdcc judge` / `claude -p` call in here fork-bombs the machine — the
#   judge's own `claude -p` re-triggers this same Stop hook, which runs this
#   script again, which spawns more judges … unbounded exponential recursion.
#
# Genuinely un-mechanizable requirements (writing quality, "is the narrative
# honest?") do NOT belong here. Record them in `.goal-driven/SOFT.md`; the
# goal-verifier judges those ONCE at the final gate, in its own context —
# never inside the loop.
#
#   check <id> <desc> -- <cmd...>   a DETERMINISTIC check; exits non-zero on fail
# ============================================================================
set -uo pipefail
FAILS=0

check() {  # check <id> <desc> -- <command...>
  local id="$1" desc="$2"; shift 2
  [ "${1:-}" = "--" ] && shift
  local out
  if out="$("$@" 2>&1)"; then
    printf '[PASS] %-5s %s\n' "$id" "$desc"
  else
    FAILS=$((FAILS+1))
    printf '[FAIL] %-5s %s\n' "$id" "$desc"
    printf '%s\n' "$out" | tail -8 | sed 's/^/         | /'
  fi
}

echo "== JUDGE SCOREBOARD =="

# ---- criteria go here (one line per acceptance requirement in GOAL.md) --------
# check C1 "unit tests pass"     -- python3 -m unittest discover -s tests -p 'test_*.py' -q
# check C2 "no type errors"      -- mypy src
# check C3 "p95 latency < 200ms" -- python3 bench/p95.py --max-ms 200
# Un-mechanizable (writing quality, honesty of a report)? Do NOT invent an LLM
# call here — add it to .goal-driven/SOFT.md; goal-verifier judges it at the end.
#
# Initial not-yet-implemented state (criteria-designer replaces this line):
check C0 "criteria not implemented yet" -- false
# -----------------------------------------------------------------------------

echo "-----------------------"
if [ "$FAILS" -eq 0 ]; then
  echo "RESULT: all criteria PASS"; exit 0
else
  echo "RESULT: $FAILS criterion(s) FAILED"; exit 1
fi
