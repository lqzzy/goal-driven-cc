# CRITERIA — the acceptance bar the strict-verifier judges against

<!--
  This is the SENSOR of the control loop. The strict-verifier (a fresh, read-only
  LLM instance) reads this file + the actual artifacts and returns, per criterion,
  [PASS] or [FAIL] with a reason — then `gdcc verdict record` stamps verdict.json.

  Rules for good criteria (the criteria-designer fills these in from the approved GOAL):
   * One row per "Success looks like" requirement in GOAL.md — cover them 1:1.
   * Each criterion must be VERIFIABLE from concrete evidence: a file, a command's
     output, a metric, a diff, a test result — name exactly what the verifier reads.
   * Prefer objective thresholds ("p95 < 200ms", "all 47 tests pass", "output byte-
     identical to golden") over vague adjectives. State the pass condition sharply
     enough that two independent verifiers would agree.
   * Freeze what must NOT change (e.g. "the physics/config dicts are byte-identical
     to golden") so a worker cannot pass by moving the goalposts.
   * The verifier does NOT run the workload; it judges EVIDENCE that already exists.
     If a criterion needs a fresh run, say which artifact the worker must produce
     first (e.g. "artifacts/log.opt from harness/bench.sh"), and mark it FAIL until
     that artifact is present and current.

  This file is FROZEN at seal (its hash is part of the tamper checksum). A worker
  must never edit it — solve the goal for real instead.
-->

## How the verifier must judge
- Read each criterion below, gather the named evidence, decide [PASS]/[FAIL] strictly.
- Missing/oudated evidence → [FAIL] with what's missing. Never give benefit of the doubt.
- Be adversarial: would an empty stub or a shortcut that games the letter of the rule
  still be [FAIL]? If a criterion could be passed by cheating, it is too weak — but you
  judge it as written; flag the weakness in your reason.

## Criteria
<!-- criteria-designer replaces the examples below with the real, GOAL-derived rows -->

### C1 — <one-line requirement>
- **Requires:** <the sharp, measurable pass condition>
- **Evidence:** <exact file / command output / metric the verifier reads>
- **Pass when:** <objective condition, e.g. "tests/ all green", "value within tolerance">

### C2 — <one-line requirement>
- **Requires:** <...>
- **Evidence:** <...>
- **Pass when:** <...>

<!-- Initial not-yet-implemented state — the criteria-designer replaces this block.
     Until real criteria exist, the verifier must record C0 as [FAIL] so the loop
     never counts an empty bar as met. -->
### C0 — criteria not implemented yet
- **Requires:** real criteria derived from GOAL.md
- **Evidence:** this file still contains the C0 placeholder
- **Pass when:** never (placeholder) — [FAIL] until C1.. replace it
