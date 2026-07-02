<!-- Static "how to work" note appended to every worker iteration. Kept positive
     and short on purpose: anti-cheat is enforced mechanically (the judge is
     checksum-sealed; a separate verifier audits), not by piling on prohibitions. -->

- Target the specific `[FAIL]` lines in the scoreboard above — each names a
  criterion and why it failed. Fix the highest-leverage one first.
- Make the smallest real change that turns a `[FAIL]` into `[PASS]`. Keep edits
  localized and reversible.
- Verify before you finish: run `bash .goal-driven/CRITERIA.sh` and confirm you
  moved at least one criterion to `[PASS]` (and broke none).
- Solve the underlying problem, not the test text. The judge is sealed and a
  separate verifier will audit — editing CRITERIA.sh or the tests only wastes a turn.
- Append ONE line to `.goal-driven/PROGRESS.md`: what you changed, which criterion
  moved, and your best next step. This is the loop's memory across fresh contexts.
