---
description: Start a goal-driven task by co-designing the GOAL with the human, then generating the CRITERIA.md acceptance bar the strict-verifier judges — a short, human-readable flow, then seal. Use when the user says "goal-driven this", "set up a goal / new objective", "define done for X", or describes a target to drive to completion.
argument-hint: <one-line goal, e.g. "implement an LRU cache that passes the given tests">
---

# /goal-driven:new — co-design a sealed, verifiable goal (loop A)

The user's one-line goal: **$ARGUMENTS**

The GOAL + CRITERIA are the **sensor** of the control loop — if they're wrong, the loop confidently converges to the wrong thing, and only the human can validate **intent**. So this phase is human-led. It is deliberately short: nail the GOAL with the human, derive the criteria as a plain-language `CRITERIA.md` the human can read and okay, then seal. The technical route is NOT decided here — it's planned at run time (loop B).

Instructions in English; **every message to the user is in 简体中文**. Do NOT arm or start the worker loop here — stop once sealed and hand off. **Ask as many clarifying questions as the goal genuinely needs — no 2–3 question cap.**

## Setup
1. **Goal present?** If `$ARGUMENTS` is empty, ask the user (中文) for the one-line goal.
2. **Scaffold.** If there is no `.goal-driven/`, run `gdcc init`. (If `gdcc` is missing: tell the user to `/plugin install goal-driven@goal-driven-cc`.)
3. **Recon.** Read the repo (language, test runner, build/run, conventions) so the drafts are grounded, not generic.

## Gate 1 — GOAL (what "done" means) — the deep gate
- Spawn `goal-analyst` (Task) with the one-liner + everything learned → it drafts `.goal-driven/GOAL.md` (Intent, "Success looks like" as numbered objectively-checkable requirements, Non-goals, Constraints, Assumptions).
- **Verifiability gate:** if it reports the goal is not auto-verifiable, relay its 中文 explanation + proposed proxies and work WITH the human to pick a verifiable proxy (or stop if none is acceptable).
- Present the GOAL in 简体中文; iterate on requirements/boundaries/assumptions until the human **explicitly approves**. This numbered list is the contract the criteria cover 1:1 — get it exactly right, because everything downstream inherits it.

## Gate 2 — CRITERIA.md (how "done" is measured)
- Spawn `criteria-designer` (Task) → it writes `.goal-driven/CRITERIA.md`: one criterion per GOAL requirement (1:1), each with a sharp **Pass when** condition and the exact **Evidence** the strict-verifier will read. No scripts, no baselines — it's the plain-language acceptance bar.
- **Present CRITERIA.md in 简体中文 and let the human read it directly** (unlike bash, this is human-auditable). Iterate: is any threshold wrong, any requirement unmeasured, any criterion gameable as written (could an empty stub pass it)? The designer tightens on the human's feedback. Advance only on the human's **explicit approval** — this is the sensor; a wrong sensor means confident wrong convergence.

## Seal
Run `gdcc seal` — instant, unconditional. It locks a tamper checksum of `GOAL.md` + `CRITERIA.md`, so a worker can't silently rewrite the goalposts mid-run (even via Bash, which the edit-guard can't catch). Nothing to audit: the human already read and approved the criteria, and every criterion is judged live by an independent strict-verifier.

## Report (中文) + hand off
Present: 一句话目标 + 已确认的关键假设;判据清单(每条的 Pass-when 要点)+ 任何未覆盖的残余风险;判据已盖章 ✅;启动方式:
- 启动无人值守闭环(全程在对话内,含技术路线规划):`/goal-driven:run`
- 查看进度:`/goal-driven:status`

Give a short 中文 status line before each subagent hand-off.
