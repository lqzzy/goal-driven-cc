---
description: Show the current goal-driven task's progress — the live JUDGE scoreboard (which criteria pass/fail and why), whether the criteria are sealed and untampered, iteration count, and recent progress. Use when the user asks how the goal-driven loop is doing or what's left.
---

# /goal-driven:status — check the loop

Instructions in English; **report to the user in 简体中文**.

1. Run `gdcc status` (iteration count, seal state + checksum integrity, armed state).
2. Run `gdcc check` to get the live JUDGE SCOREBOARD — which criteria `[PASS]`/`[FAIL]` and why.
3. Summarize for the user in 中文:
   - 判据是否已盖章、校验和是否一致(若显示被改动,警示 CRITERIA 被篡改);
   - 当前记分板:哪些条件已过、哪些未过 + 原因;
   - 迭代数、是否停滞/无进展、会话门是否 armed;
   - `.goal-driven/PROGRESS.md` 最近几条;
   - 下一步建议:继续 `/goal-driven:run` / 需要人介入(停滞或判据有问题) / 已达成可让 `goal-verifier` 复核。
