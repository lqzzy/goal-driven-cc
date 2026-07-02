#!/usr/bin/env bash
# Judge for the is-prime example — per-criterion scoreboard.
# Exit 0 iff every criterion passes. Relocatable, no third-party deps.
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
check C1 "python3 available"            -- command -v python3
check C2 "is_prime tests all pass"      -- python3 -m unittest discover -s tests -p 'test_*.py' -q
echo "-----------------------"

if [ "$FAILS" -eq 0 ]; then
  echo "RESULT: all criteria PASS"; exit 0
else
  echo "RESULT: $FAILS criterion(s) FAILED"; exit 1
fi
