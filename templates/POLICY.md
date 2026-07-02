# Autonomy Policy

Read by the auto-decider when the run is unattended. It encodes YOUR pre-agreed
answers to predictable forks, so the loop never pauses for you. The decider takes
these defaults on ROUTINE forks. Anything that would change/relax the GOAL or
criteria is NOT decided here — it goes to a strict reachability panel, which
escalates to you only if it proves the goal genuinely unreachable.

## Routine forks — decide and continue (never ask the human)
- A worker/subagent dies from a transient API error ("Connection closed", 5xx,
  timeout) → restart a fresh worker (up to 3 attempts), then continue.
- Two viable technical approaches → pick the one most likely to move a `[FAIL]`
  to `[PASS]`; record the choice in PROGRESS.md.
- Unsure which failing criterion to tackle first → take the highest-leverage one.
- A setup/tooling detail with an obvious sane default → take the default, log it.

## Never do autonomously
- Never relax, drop, reword, or edit the GOAL or any criterion. The success bar
  is frozen once sealed (and mechanically locked by checksum).
- Never declare the goal done without the criteria genuinely passing (pass^k +
  goal-verifier).
- Never bypass commit hooks, the seal, or the judge.

## Escalate to the human ONLY when
- A strict reachability panel concludes, with hard evidence, that the target is
  genuinely UNREACHABLE (e.g. a physical/hardware limit, a contradictory
  requirement), or
- A decision is irreversible and not covered by this policy.

<!-- Edit this file per task: add domain-specific routine defaults, tighten what
     counts as "unreachable", or adjust the escalation bar. -->
