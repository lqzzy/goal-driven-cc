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
#   * Deterministic and FAST for hard checks (see GDCC_CRITERIA_BUDGET).
#
# Two kinds of criterion:
#   check <id> <desc> -- <cmd...>          a DETERMINISTIC check (tests/compile/grep)
#   soft  <id> <desc> <rubric> <question>  an LLM verdict for something you CANNOT
#                                          check mechanically (via a fresh, strict,
#                                          independent `gdcc judge` instance)
# Prefer `check` wherever a mechanical test is possible; reserve `soft` for
# genuinely un-testable criteria. The criteria-designer fills in the real ones.
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

soft() {  # soft <id> <desc> <rubric-file> <question>
  local id="$1" desc="$2" rubric="$3" question="$4"
  local out
  if out="$(gdcc judge --rubric "$rubric" "$question" 2>&1)"; then
    printf '[PASS] %-5s %s (soft)\n' "$id" "$desc"
  else
    FAILS=$((FAILS+1))
    printf '[FAIL] %-5s %s (soft)\n' "$id" "$desc"
    printf '%s\n' "$out" | head -3 | sed 's/^/         | /'
  fi
}

echo "== JUDGE SCOREBOARD =="

# ---- criteria go here (one line per acceptance requirement in GOAL.md) --------
# check C1 "unit tests pass"    -- python3 -m unittest discover -s tests -p 'test_*.py' -q
# check C2 "no type errors"     -- mypy src
# soft  C3 "docs are clear"     rubric.md "Does report.md explain the algorithm and include p95 latency with its measurement method?"
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
