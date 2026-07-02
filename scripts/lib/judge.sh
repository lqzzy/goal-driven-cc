#!/usr/bin/env bash
# ============================================================================
# judge.sh -- `gdcc judge` : a STRICT, INDEPENDENT LLM verdict for one
# criterion that cannot be checked mechanically. Returns exit 0 (PASS) / 1 (FAIL)
# so it composes inside CRITERIA.sh like any other check:
#
#     gdcc judge --rubric rubric.md "Does the report include p95 latency numbers?"
#
# It spawns a FRESH read-only `claude -p` instance (never the worker's context),
# so it cannot grade its own homework. Non-deterministic by nature -> pair with
# GDCC_CONSECUTIVE_PASSES so a lucky single PASS does not end the loop.
# Usage: judge.sh [--rubric <file>] "<question>"
# ============================================================================
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

RUBRIC=""; QUESTION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rubric) RUBRIC="${2:-}"; shift 2;;
    *) QUESTION="$1"; shift;;
  esac
done
[ -n "$QUESTION" ] || gd_die "judge: 需要一个问题,例如 gdcc judge \"报告是否包含 p95 延迟\""

DIR="$(gd_find_task_dir "$PWD" 2>/dev/null || true)"
[ -n "$DIR" ] && [ -f "$DIR/config.env" ] && { set -a; source "$DIR/config.env"; set +a; }
MODEL="${GDCC_JUDGE_MODEL:-}"

rubric_text=""
[ -n "$RUBRIC" ] && [ -f "$RUBRIC" ] && rubric_text="$(cat "$RUBRIC")"

command -v claude >/dev/null 2>&1 || { echo "judge ERROR: claude CLI not found"; exit 2; }

prompt="You are a STRICT, INDEPENDENT verifier. You did NOT write this code and must not give it the benefit of the doubt. Judge ONLY the question below against the ACTUAL repository state — read the relevant files yourself before deciding. Be skeptical: actively look for reasons it FAILS.

QUESTION: ${QUESTION}
"
[ -n "$rubric_text" ] && prompt="${prompt}
RUBRIC:
${rubric_text}
"
prompt="${prompt}
Decide, then end your reply with EXACTLY one final line, nothing after it:
VERDICT: PASS
— or —
VERDICT: FAIL — <one concise reason>
Only answer PASS if the question is fully and genuinely satisfied."

out="$(gd_timeout "${GDCC_JUDGE_TIMEOUT:-300}" claude -p "$prompt" \
        --allowedTools Read Grep Glob \
        ${MODEL:+--model "$MODEL"} \
        --output-format text 2>/dev/null)"

if printf '%s\n' "$out" | grep -qE '^VERDICT:[[:space:]]*PASS'; then
  echo "judge PASS: ${QUESTION}"
  exit 0
fi
reason="$(printf '%s\n' "$out" | grep -E '^VERDICT:[[:space:]]*FAIL' | head -1)"
[ -z "$reason" ] && reason="VERDICT: FAIL — verifier returned no clear verdict"
echo "judge FAIL: ${QUESTION} — ${reason#VERDICT: FAIL }"
exit 1
