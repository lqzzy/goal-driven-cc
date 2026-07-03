---
description: Start a goal-driven task by DEEPLY co-designing the goal, criteria, and technical roadmap WITH the human — staged approval gates, ask as many questions as it takes, then a light mechanical + one-pass coverage check, then seal. Use when the user says "goal-driven this", "set up a goal / new objective", "define done for X", or describes a target to drive to completion.
argument-hint: <one-line goal, e.g. "implement an LRU cache that passes the given tests">
---

# /goal-driven:new — co-design a sealed, verifiable goal (loop A)

The user's one-line goal: **$ARGUMENTS**

The goal + criteria + roadmap are the single most consequential artifacts in the whole run — they are the **sensor** and the **route** of the control loop; if they are wrong, the loop confidently converges to the wrong thing. A machine can only check whether the criteria are internally sound (empty/cheat fail, coverage) — it **cannot** check whether they match what the human actually wants. Only the human can validate **intent**. So this phase is **human-led co-design, not machine auto-audit**: get the human to a satisfied "yes" on each artifact first, THEN do a cheap objective sanity check, THEN seal.

Instructions in English; **every message to the user is in 简体中文**. Do NOT arm or start the worker loop here — stop once sealed and hand off. **Ask as many clarifying questions as the goal genuinely needs — there is NO 2–3 question cap; the whole point is to get it right with the human.**

## Setup
1. **Goal present?** If `$ARGUMENTS` is empty, ask the user (中文) for the one-line goal.
2. **Scaffold.** If there is no `.goal-driven/`, run `gdcc init`. (If `gdcc` is missing: tell the user to `/plugin install goal-driven@goal-driven-cc`.)
3. **Recon.** Read the repo (language, test runner, build/run, conventions) so the drafts are grounded, not generic.

## Staged approval gates — each artifact is co-designed and human-approved before the next
Present every draft in 简体中文, plainly. At each gate: **show the draft → ask targeted questions** (AskUserQuestion for discrete choices, free-form for edits) **→ apply the human's edits → re-present → repeat until the human explicitly approves.** Never advance a gate on your own judgment; the human's "yes" is the only thing that opens the next gate.

**WHAT vs HOW — the human only ever approves the WHAT.** The human judges the *goal*, the *measurable acceptance conditions*, and the *high-level technical route* — all in plain language. They never have to review the HOW — the `CRITERIA.sh` scripts, test code, or baseline code — because a human can't meaningfully audit bash/python, and they don't need to: the **audit** (by default a read-only `criteria-auditor` subagent that statically reasons about whether empty/cheat solutions would be rejected) checks that the script discriminates. Division of labor: the human verifies the criteria match their intent (semantic); the machine reviews that the scripts correctly measure the criteria. Neither does the other's job.

**Gate 1 — GOAL (what "done" means).**
- Spawn `goal-analyst` (Task) with the one-liner + everything learned so far → it drafts `.goal-driven/GOAL.md` (Intent, "Success looks like" as numbered objectively-checkable requirements, Non-goals, Constraints, Assumptions).
- **Verifiability gate:** if it reports the goal is not auto-verifiable, relay its 中文 explanation + proposed proxies, and work WITH the human to pick a verifiable proxy (or stop if none is acceptable).
- Present the GOAL; iterate on requirements, boundaries, and assumptions until the human approves. This numbered list is the contract the criteria must cover 1:1 — get it exactly right here, because everything downstream inherits it.

**Gate 2 — CRITERIA (how "done" is measured) — approve the WHAT, then the machine implements the HOW.**
- **2a — agree the measurable acceptance conditions (WHAT; the human approves this).** Spawn `criteria-designer` (Task) in **spec-first** mode: it proposes, in plain 简体中文, a **measurable acceptance table** — each GOAL requirement → a concrete measurable condition/threshold + one phrase on how it will be decided mechanically (e.g. `C2: p95 latency < 200ms`, `C1: all 47 provided tests pass`, `C3: empty input exits 0, no stack trace`). It writes NO scripts yet, and flags any requirement that cannot be made mechanical as a **semantic choice for you** (accept a proxy / drop / mark soft-judge). Present the table; iterate on thresholds/conditions with the human until they approve. **This is where the run is won or lost** — only the human can catch "that measures the wrong thing", and getting it right here costs nothing (it's just text; no scripts have been written).
- **2b — implement + mechanically audit (HOW; machine-only, no human review).** Once the table is approved, the same `criteria-designer` turns it into `.goal-driven/CRITERIA.sh` (`check` for mechanical / `soft`+`gdcc judge` only for genuinely un-testable), the tests, and adversarial baselines under `.goal-driven/baselines/` (`empty` + `cheat_*` required, `reference` preferred). The human does NOT approve this code — the audit below (a `criteria-auditor` static review by default) vets it. Only bounce back to the human if implementing faithfully surfaces a NEW semantic question (a threshold that turned out ambiguous, a condition that can't be measured as agreed).

**Gate 3 — 技术路线 ROADMAP (the route).**
- Spawn `goal-planner` (Task, roadmap mode) → it drafts `.goal-driven/ROADMAP.md` (2–6 ordered phases, each with target criteria + exit condition + approach + risks).
- Present in 简体中文. The human often has strong opinions on the technical approach — let them reorder phases, swap the approach, flag risks, rule an angle in or out. Iterate until approved. This is the human-approved **starting** route; at run time `goal-planner` only **refines** it, and it is deliberately **not sealed/locked** — the route may evolve, only the goal/criteria are frozen.

## Audit → seal (default: fast agent review; instant seal)
The human validated intent (WHAT); now one quick check that the SCRIPTS implement it (HOW). **Default = an agent reads them — no heavy execution**, because for expensive criteria running them ×N is the slow part.
4. **Audit (default = agent static review; advisory).** Spawn `criteria-auditor` (Task) in **STATIC mode**: it READS GOAL + CRITERIA.sh + baselines and judges — would the `empty` stub be rejected? would each `cheat_*` baseline be rejected? does every approved acceptance condition have a real check (coverage)? It does **not** execute the heavy workload. This is **advisory**: relay its verdict in 简体中文, and if it flags a broken/gameable check or a coverage gap, the human decides — patch via `criteria-designer` (re-spawn for that one thing) or accept. It never blocks the seal.
   - **Opt-in executed proof:** if the task's `.goal-driven/config.env` sets `GDCC_AUDIT_LEVEL=lite` (or `full`), run `gdcc audit` instead — it EXECUTES the empty/cheat baselines to *prove* rejection (lite ≈ 2 runs; full adds determinism + reference). Use it when `CRITERIA.sh` is cheap to run or the goal is high-stakes.
5. **Seal (instant, unconditional).** Run `gdcc seal`. It runs **no** audit and always succeeds — it only locks a checksum of GOAL.md + CRITERIA.sh + judge/ for tamper detection (what stops a worker silently rewriting the goalposts mid-run, even via Bash). The review already happened in step 4.

## Report (中文) + hand off
Present: 一句话目标 + 已确认的关键假设;判据覆盖矩阵要点 + 挡住的作弊路径;技术路线的阶段列表;判据已盖章 ✅;启动方式:
- 启动无人值守闭环(全程在对话内):`/goal-driven:run`
- 查看进度:`/goal-driven:status`

Give a short 中文 status line before each subagent hand-off.
