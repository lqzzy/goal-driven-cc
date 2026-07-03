#!/usr/bin/env bash
# ============================================================================
# guard.sh -- PreToolUse guard for autonomous goal-driven runs.
# INERT unless the cwd tree has an ARMED .goal-driven task. When armed:
#   * blocks edits to the sealed GOAL.md / CRITERIA.sh / judge/ (no moving the goalposts)
#   * hard-blocks `--no-verify`; strict profile also blocks force-push / hard-reset
#   * logs (does NOT block) obviously destructive commands
# Blocking uses the PreToolUse contract: exit 2 + reason on stderr. Fail-open.
# ============================================================================
set -uo pipefail
source "$(dirname "$0")/lib/common.sh" 2>/dev/null || exit 0

input="$(cat 2>/dev/null || true)"
DIR="$(gd_find_task_dir "$PWD" 2>/dev/null || true)"
[ -n "$DIR" ] && [ -f "$DIR/ACTIVE" ] || exit 0
[ -f "$DIR/config.env" ] && { set -a; source "$DIR/config.env" 2>/dev/null; set +a; }
profile="${GDCC_SAFETY_PROFILE:-standard}"

tool=""; cmd=""; fpath=""
if command -v jq >/dev/null 2>&1; then
  tool="$(printf '%s' "$input" | jq -r '.tool_name // .tool // empty' 2>/dev/null)"
  cmd="$(printf '%s'  "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  fpath="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
fi

# --- quota preemption gate: halt ALL work the moment 5h usage hits the ceiling ---
# Fires before every action tool (incl. inside a running worker subagent), so work
# is interrupted at its next tool call. Allowlists the master's own quota-control
# commands so it can still wait-until-reset and resume (no deadlock).
if [ "${GDCC_QUOTA_GATE:-1}" = 1 ]; then
  gpct="$(gd_quota_pct5 2>/dev/null || true)"
  if [ -n "$gpct" ] && [ "$gpct" -ge "${GDCC_QUOTA_PAUSE_AT:-90}" ]; then
    case "$cmd" in
      *"gdcc quota"*|*"gdcc status"*|*"reset-epoch"*|*"date +%s"*) : ;;  # master control — allow
      *)
        echo "goal-driven quota-gate: 5h usage ${gpct}% >= ${GDCC_QUOTA_PAUSE_AT:-90}% ceiling. STOP working now and return control to the master. The master must wait until the quota window resets (background: until [ \"\$(date +%s)\" -ge \"\$(gdcc quota reset-epoch)\" ]; do sleep 120; done) and then resume. Do not make further tool calls until then." >&2
        exit 2 ;;
    esac
  fi
fi

# --- protect the sealed goal + judge from edits during a run ---
case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit)
    case "$fpath" in
      */.goal-driven/GOAL.md|*/.goal-driven/CRITERIA.sh|*/.goal-driven/judge/*)
        echo "goal-driven guard: blocked an edit to the sealed goal/judge ($fpath). The success bar is fixed for this run — solve the goal, don't move the goalposts. If the goal is genuinely wrong, that must be escalated, not edited." >&2
        exit 2;;
    esac
    ;;
esac

# --- bash protections ---
case "$cmd" in
  *--no-verify*)
    echo "goal-driven guard: blocked '--no-verify'. An autonomous worker must not bypass commit/pre-push hooks." >&2
    exit 2;;
esac
if [ "$profile" = "strict" ]; then
  case "$cmd" in
    *"push"*"--force"*|*"push --force"*|*"push -f "*|*"reset --hard"*)
      echo "goal-driven guard (strict): blocked a history-rewriting command during an unattended run: $cmd" >&2
      exit 2;;
  esac
fi
case "$cmd" in
  *"rm -rf /"*|*"DROP TABLE"*|*"mkfs"*|*":(){ :|:& };:"*)
    mkdir -p "$DIR/logs" 2>/dev/null
    printf '%s DANGER %s\n' "$(gd_now)" "$cmd" >> "$DIR/logs/governance.log" 2>/dev/null || true;;
esac
exit 0
