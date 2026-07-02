#!/usr/bin/env bash
# check.sh -- the Judge gate. Runs .goal-driven/CRITERIA.sh from the project root.
# Exit code 0 = goal reached; non-zero = not reached (its stdout is "what's missing").
# Usage: check.sh [task-dir]   (defaults to nearest .goal-driven/ above $PWD)
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DIR="${1:-}"
[ -z "$DIR" ] && { DIR="$(gd_find_task_dir "$PWD")" || { echo "check: no .goal-driven/ task dir found" >&2; exit 3; }; }
CRIT="$DIR/CRITERIA.sh"
[ -f "$CRIT" ] || { echo "check: missing $CRIT" >&2; exit 3; }

ROOT="$(dirname "$DIR")"
mkdir -p "$DIR/logs"
( cd "$ROOT" && bash "$CRIT" )
exit $?
