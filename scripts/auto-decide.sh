#!/usr/bin/env bash
# ============================================================================
# auto-decide.sh -- PreToolUse detector for AskUserQuestion (LOG ONLY).
#
# Reality check (Anthropic issue #12605): a hook CANNOT answer AskUserQuestion —
# there is no mechanism to feed an answer back, so interception cannot make a run
# unattended. The reliable mechanism is to DISABLE the tool (see `gdcc arm`, which
# writes disallowedTools to the project settings, or launch with
# `claude --disallowedTools AskUserQuestion`) so the agent can never call it.
#
# This hook therefore only LOGS if a question slips through while armed — a signal
# that the disable did not take effect (e.g. the session was started without it).
# It never blocks (blocking cannot answer the question and would just stall).
# ============================================================================
set -uo pipefail
source "$(dirname "$0")/lib/common.sh" 2>/dev/null || exit 0

input="$(cat 2>/dev/null || true)"
DIR="$(gd_find_task_dir "$PWD" 2>/dev/null || true)"
[ -n "$DIR" ] && [ -f "$DIR/ACTIVE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tool="$(printf '%s' "$input" | jq -r '.tool_name // .tool // empty' 2>/dev/null)"
[ "$tool" = "AskUserQuestion" ] || exit 0

mkdir -p "$DIR/logs" 2>/dev/null
q="$(printf '%s' "$input" | jq -r '(.tool_input.questions[0].question) // .tool_input.question // "?"' 2>/dev/null)"
printf '%s LEAKED-QUESTION (AskUserQuestion was NOT disabled — restart with --disallowedTools AskUserQuestion, or re-run gdcc arm) q=%q\n' "$(gd_now)" "$q" >> "$DIR/decisions.log"
exit 0
