#!/usr/bin/env bash
# ============================================================================
# audit.sh -- Criteria audit engine (mechanical meta-criteria verification).
# ----------------------------------------------------------------------------
# Control-theory view: the criteria ARE the sensor. This script calibrates the
# sensor objectively with adversarial mutation testing, so "auto-review" is not
# "another LLM's opinion" but a mechanical fact:
#   2. discrimination floor : an EMPTY-solution baseline MUST be judged FAIL
#   4. anti-cheat           : each CHEAT-solution baseline MUST be judged FAIL
#   3. discrimination ceiling: a REFERENCE-solution baseline MUST be judged PASS (optional)
#   5. non-flaky            : N repeated runs agree
#   6. fast enough          : one criteria run < time budget
# All of these must hold before criteria may be sealed. Semantic coverage
# (meta-criterion 7) is reviewed separately by the criteria-auditor subagent.
#
# Baseline layout (produced by the criteria-designer subagent):
#   .goal-driven/baselines/empty/       solution replaced by a stub  -> expect FAIL
#   .goal-driven/baselines/cheat_*/     reward-hacking solutions      -> expect FAIL
#   .goal-driven/baselines/reference/   a known-good solution (opt.)  -> expect PASS
# Each baseline dir holds files laid out relative to the project root; they are
# overlaid onto a throwaway copy of the project, then CRITERIA.sh is run there.
#
# Usage: audit.sh [task-dir]     Exit code 0 = criteria mechanically trustworthy.
# ============================================================================
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DIR="${1:-}"
[ -z "$DIR" ] && { DIR="$(gd_find_task_dir "$PWD")" || gd_die "no .goal-driven/ task dir found"; }
ROOT="$(dirname "$DIR")"
CRIT="$DIR/CRITERIA.sh"
[ -f "$CRIT" ] || gd_die "missing $CRIT"

[ -f "$DIR/config.env" ] && { set -a; source "$DIR/config.env"; set +a; }
BUDGET="${GDCC_CRITERIA_BUDGET:-120}"
DRUNS="${GDCC_DETERMINISM_RUNS:-3}"
LEVEL="${GDCC_AUDIT_LEVEL:-agent}"         # agent (default): subagent static review (no execution) | lite: empty+cheat must-FAIL | full: +determinism+reference | off: skip
EXTRA_EXCLUDES="${GDCC_AUDIT_EXCLUDE:-}"   # extra rsync excludes for the temp copy (space-separated globs)
BASE_DIR="$DIR/baselines"
REPORT="$DIR/audit-report.md"
mkdir -p "$DIR/logs"

FAILS=0
LINES=()
row() { LINES+=("$1"); printf '%s\n' "$1"; }

# --- level agent: mechanical battery not applicable; a subagent does the static review ---
if [ "$LEVEL" = agent ]; then
  row "# Criteria Audit Report (gd-audit) — LEVEL=agent (static review by subagent)"
  row ""
  row "Mechanical battery skipped by design. The criteria are reviewed by the criteria-auditor SUBAGENT"
  row "(it reads CRITERIA.sh + baselines and judges whether empty/cheat would be rejected, WITHOUT running"
  row "the workload) — advisory only. \`gdcc seal\` then locks the checksum unconditionally. For an EXECUTED"
  row "proof instead, set GDCC_AUDIT_LEVEL=lite (empty+cheat must-FAIL) or full."
  printf '%s\n' "${LINES[@]}" > "$REPORT"
  exit 0
fi

# --- level off: mechanical audit disabled (fastest; loses anti-cheat) ---
if [ "$LEVEL" = off ]; then
  row "# Criteria Audit Report (gd-audit) — DISABLED (GDCC_AUDIT_LEVEL=off)"
  row ""
  row "Mechanical calibration SKIPPED — the criteria are NOT proven to reject empty/cheat solutions."
  row "seal will still lock a tamper-detection checksum, but there is NO anti-vacuity / anti-cheat"
  row "guarantee. Only use off for a fast throwaway loop. Set GDCC_AUDIT_LEVEL=agent (default) to restore."
  printf '%s\n' "${LINES[@]}" > "$REPORT"
  exit 0
fi

# Copy project root to a temp dir, overlay a baseline, run CRITERIA.sh there.
run_with_overlay() {
  local overlay="$1" tmp rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/gdaudit.XXXXXX")" || return 99
  if command -v rsync >/dev/null 2>&1; then
    local -a excl=( --exclude '.git' --exclude 'node_modules' --exclude '__pycache__'
                    --exclude '.venv' --exclude 'venv' --exclude 'target' --exclude 'build'
                    --exclude 'dist' --exclude '.goal-driven/logs' )
    local p
    for p in $EXTRA_EXCLUDES; do excl+=( --exclude "$p" ); done
    rsync -a "${excl[@]}" "$ROOT"/ "$tmp"/ >/dev/null 2>&1
  else
    cp -R "$ROOT"/. "$tmp"/ 2>/dev/null
    rm -rf "$tmp/.git" "$tmp/node_modules" "$tmp/.goal-driven/logs" 2>/dev/null
  fi
  [ -n "$overlay" ] && [ -d "$overlay" ] && cp -R "$overlay"/. "$tmp"/ 2>/dev/null
  ( cd "$tmp" && gd_timeout "$BUDGET" bash "$tmp/.goal-driven/CRITERIA.sh" ) >/dev/null 2>&1
  rc=$?
  rm -rf "$tmp"
  return $rc
}
verdict() { [ "$1" -eq 0 ] && echo PASS || echo FAIL; }

row "# Criteria Audit Report (gd-audit)"
row ""
row "Task: \`$DIR\`  |  level: ${LEVEL}  |  budget: ${BUDGET}s  |  determinism runs: ${DRUNS}"
row ""
row "| # | Meta-criterion | Expect | Actual | Result |"
row "|---|---|---|---|---|"

# ---- meta 5 (non-flaky) + meta 6 (fast): repeat current solution DRUNS times (full only) ----
if [ "$LEVEL" = full ]; then
  first_rc=""; determ_ok=1; t0=$(date +%s)
  for _ in $(seq 1 "$DRUNS"); do
    run_with_overlay ""; rc=$?
    [ -z "$first_rc" ] && first_rc=$rc
    [ "$(verdict "$rc")" != "$(verdict "$first_rc")" ] && determ_ok=0
  done
  t1=$(date +%s); per=$(( (t1 - t0) / DRUNS ))
  if [ "$determ_ok" -eq 1 ]; then row "| 5 | non-flaky (${DRUNS}x) | agree | agree | PASS |"; else row "| 5 | non-flaky (${DRUNS}x) | agree | **jitter** | FAIL |"; FAILS=$((FAILS+1)); fi
  if [ "$per" -le "$BUDGET" ]; then row "| 6 | fast enough | <=${BUDGET}s | ~${per}s | PASS |"; else row "| 6 | fast enough | <=${BUDGET}s | ~${per}s | FAIL |"; FAILS=$((FAILS+1)); fi
else
  row "| 5 | non-flaky | — | (skipped: lite) | SKIP |"
  row "| 6 | fast enough | — | (skipped: lite) | SKIP |"
fi

# ---- meta 2 (floor) + meta 4 (anti-cheat) + meta 3 (ceiling) via baselines ----
have_empty=0; have_cheat=0
if [ -d "$BASE_DIR" ]; then
  for b in "$BASE_DIR"/*/; do
    [ -d "$b" ] || continue
    name="$(basename "$b")"
    # reference is the expensive "ceiling" check (runs a full correct solution) — full only
    case "$name" in
      reference*) if [ "$LEVEL" != full ]; then row "| 3 | reference baseline \`$name\` | PASS | (skipped: lite) | SKIP |"; continue; fi ;;
    esac
    run_with_overlay "$b"; v="$(verdict $?)"
    case "$name" in
      empty*)     have_empty=1; if [ "$v" = FAIL ]; then row "| 2 | empty baseline \`$name\` | FAIL | $v | PASS |"; else row "| 2 | empty baseline \`$name\` | FAIL | $v | FAIL |"; FAILS=$((FAILS+1)); fi ;;
      cheat*)     have_cheat=1; if [ "$v" = FAIL ]; then row "| 4 | cheat baseline \`$name\` | FAIL | $v | PASS |"; else row "| 4 | cheat baseline \`$name\` | FAIL | $v | FAIL |"; FAILS=$((FAILS+1)); fi ;;
      reference*) if [ "$v" = PASS ]; then row "| 3 | reference baseline \`$name\` | PASS | $v | PASS |"; else row "| 3 | reference baseline \`$name\` | PASS | $v | FAIL |"; FAILS=$((FAILS+1)); fi ;;
      *)          row "| - | unknown baseline \`$name\` (skipped) | - | - | SKIP |" ;;
    esac
  done
fi

# ---- fail-closed: without empty/cheat baselines the criteria are untested ----
[ "$have_empty" -eq 0 ] && { row "| 2 | empty baseline | required | **missing** | FAIL |"; FAILS=$((FAILS+1)); }
[ "$have_cheat" -eq 0 ] && { row "| 4 | cheat baseline | required | **missing** | FAIL |"; FAILS=$((FAILS+1)); }

row ""
if [ "$FAILS" -eq 0 ]; then
  if [ "$LEVEL" = full ]; then
    row "## Verdict: PASS -- criteria are mechanically trustworthy (meta 2-6)."
  else
    row "## Verdict: PASS (lite) -- empty & cheat baselines are correctly rejected (meta 2 + 4, the anti-cheat floor). Determinism (meta 5) and reference-ceiling (meta 3) NOT checked; run GDCC_AUDIT_LEVEL=full for those — recommended if CRITERIA.sh uses soft/gdcc judge."
  fi
  row "Next: criteria-auditor subagent must still review semantic coverage (meta 7: every GOAL requirement maps to an assertion)."
else
  row "## Verdict: FAIL -- $FAILS check(s) failed. Criteria must NOT be sealed."
  row "criteria-designer must strengthen them (add baselines / tighten assertions / remove flakiness / speed up)."
fi

printf '%s\n' "${LINES[@]}" > "$REPORT"
exit "$FAILS"
