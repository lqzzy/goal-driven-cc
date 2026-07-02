---
description: Start a goal-driven task from a one-line goal — clarify it, synthesize a verifiable Judge (CRITERIA.sh + adversarial baselines), and auto-audit until sealed, without starting the worker loop. Use when the user says "goal-driven this", "set up a goal / new objective", "define done for X", or describes a target they want driven to completion autonomously.
argument-hint: <one-line goal, e.g. "implement an LRU cache that passes the given tests">
---

# /goal-driven:new — build a sealed, verifiable goal (loop A)

The user's one-line goal: **$ARGUMENTS**

Run the full loop-A pipeline. Instructions in English; **every message to the user is in 简体中文**. Do NOT start the worker loop here — stop once the criteria are sealed and hand off launch instructions.

## Steps
1. **Goal present?** If `$ARGUMENTS` is empty, ask the user (中文) for the one-line goal.
2. **Scaffold.** If there is no `.goal-driven/`, run `gdcc init`. (If `gdcc` is missing: tell the user to `/plugin install goal-driven@goal-driven-cc`.)
3. **Recon + clarify.** Quickly read the repo (language, test runner, build/run, conventions). Then ask the user **2–3 sharp clarifying questions** with AskUserQuestion (boundaries, what counts as done, hard constraints). Skip anything you can safely infer.
4. **Analyze → GOAL.md.** Spawn `goal-analyst` (Task) with the one-liner + answers. **Verifiability gate:** if it reports the goal is not auto-verifiable, relay its 中文 explanation + proposed proxies and stop.
5. **Design criteria.** Spawn `criteria-designer` (Task). It writes `.goal-driven/CRITERIA.sh` as a per-criterion scoreboard — `check` for mechanically testable requirements, `soft`/`gdcc judge` only for genuinely un-testable ones — plus tests and adversarial baselines (`empty` + `cheat_*` required, `reference` preferred).
6. **Audit → seal.** Spawn `criteria-auditor` (Task). It runs `gdcc audit` (mechanical) + coverage review, then either returns fixes (re-spawn `criteria-designer` with them; **at most 3 rounds**) or seals. Sealing (`gdcc seal`) also verifies the criteria **fail on the untouched code** (else they are vacuous) and locks a checksum so the worker can't later edit the judge.
7. **Report (中文) + hand off.** Present: 一句话目标 + 关键假设(请确认);判据覆盖矩阵要点 + 挡住了哪些作弊路径;判据已盖章 ✅;启动方式:
   - 启动无人值守闭环(全程在对话内):`/goal-driven:run`
   - 查看进度:`/goal-driven:status`

Give a short 中文 status line before each subagent hand-off.
