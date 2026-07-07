<!-- Static "how to work" note appended to every worker iteration. Kept positive
     and short on purpose: anti-cheat is enforced mechanically (the goalposts are
     checksum-sealed; a separate strict-verifier judges), not by piling on prohibitions. -->

- Target the specific `[FAIL]` lines in the verdict scoreboard above — each names a
  criterion and why the strict-verifier failed it. Fix the highest-leverage one first;
  cross-reference `.goal-driven/CRITERIA.md` for the exact acceptance condition.
- Make the smallest real change that satisfies a failing criterion. Keep edits
  localized and reversible; produce any artifact the criterion names.
- Verify before you finish by running the actual test / build / command the criterion
  references — confirm it now holds (and you broke none). The strict-verifier judges
  afterward and only scores evidence you've produced.
- Solve the underlying problem, not the criteria text. The goalposts are sealed and a
  separate strict-verifier judges — editing GOAL.md/CRITERIA.md only wastes a turn.
- Append ONE line to `.goal-driven/PROGRESS.md`: what you changed, which criterion
  moved, and your best next step. This is the loop's memory across fresh contexts.
