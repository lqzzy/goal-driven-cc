---
description: Revise the goal, criteria, and technical roadmap of an EXISTING goal-driven task — re-walk the co-design gates, but grounded in current progress and with deep human involvement. Use mid-run when what you've learned means the goal/criteria must change — "the criterion is wrong", "redefine the goal based on where we are", "重写目标/判据", "基于进度重定判据", or to resolve an escalation by revising rather than resuming.
argument-hint: (optional: what to revise / why)
---

# /goal-driven:revise — human-led goal/criteria revision, grounded in progress

Revise focus (optional): **$ARGUMENTS**

Sometimes a run teaches you that the goal or criteria themselves need to change — a threshold was wrong, a criterion measures the wrong thing, the real intent surfaced only after building, or an escalation proved a bar unreachable as written. This is the ONE sanctioned, auditable way to change a sealed goal: **the human re-authors it**, deeply, informed by everything the run has learned. It is NOT the agent relaxing the goal on its own (that never happens) — it is you exercising your authority to redefine, with the agent as co-designer.

Instructions in English; **every message to the user is in 简体中文**. This is interactive throughout — do NOT run unattended here. Ask as many questions as it takes.

## Preconditions
Run `gdcc status`. If there is no `.goal-driven/` task, tell the user (中文) to use `/goal-driven:new` instead, and stop. Revise is for an EXISTING task; `new` is for a blank one.

## Step 1 — ground the revision in reality (this is what makes revise ≠ new)
Before proposing any change, read the ACTUAL state so the co-design is informed, not generic:
- `.goal-driven/GOAL.md`, `CRITERIA.md`, `ROADMAP.md` — the current contract + route.
- **Live scoreboard:** run `gdcc check` — the last strict-verifier verdict (which criteria are `[PASS]` / `[FAIL]`, and whether it's fresh).
- `PROGRESS.md`, `decisions.log`, `ESCALATION.md` (if present) — what was tried, what was learned, what's stuck and why.
- The relevant code/results/benchmarks, so a claim like "C2 is unreachable" is checked against evidence, not taken at face value.

Present a short 简体中文 **current-state briefing**: 当前目标一句话 / 判据现状(过了哪几条、卡在哪条、为什么)/ 已学到的关键事实 / 这次想改什么。The human decides with full knowledge of where things stand.

## Step 2 — enter revise mode (snapshot + unlock)
Run `gdcc revise-begin "<one-line why>"`. It snapshots the current GOAL/CRITERIA/ROADMAP (+judge) into `.goal-driven/history/` (auditable + rollbackable), disarms (the guard goes inert so edits are allowed), unseals (unlocks the checksum), and logs the revision start to `decisions.log`. **The old goal is archived, never silently overwritten.**

## Step 3 — revise the goalposts, seeded with progress (same rigor as `/goal-driven:new`)
Re-walk the two gates, but each draft is a **revision** of the current artifact informed by Step 1 — not a blank redo. Present in 简体中文, iterate, and advance ONLY on the human's explicit approval. (The technical route is not revised here — it's re-planned at run time; revise only touches the sealed goalposts.)

**Gate 1 — GOAL.** Spawn `goal-analyst` (Task) with the current GOAL.md + the progress briefing + the human's revise intent. It proposes a **revised** GOAL: keep what still holds, change what the evidence/human says to change, and call out exactly what moved and why. The verifiability gate still applies. Iterate → approve.

**Gate 2 — CRITERIA.md.** Spawn `criteria-designer` (Task) → it revises `.goal-driven/CRITERIA.md`, showing **old→new** for what changed and **preserving criteria that still hold** (don't churn passing ones). Guard against "relaxing a criterion just to turn red green": every change must trace to a GOAL change the human approved. Present in 简体中文, let the human read it directly, iterate on thresholds/coverage/gameability → human approves.

## Step 4 — re-seal (only after the human is satisfied)
- **Re-seal (instant, unconditional).** Run `gdcc seal` — it locks the new `GOAL.md` + `CRITERIA.md` checksum. No audit: the human read and approved the revised criteria, and the strict-verifier judges them live. If the revised goal is already met by the work built so far, that's fine: `/goal-driven:run` will just verify (pass^k + goal-verifier) and finish.
- Append a one-line old→new summary to `.goal-driven/decisions.log`.

## Step 5 — hand off (简体中文)
Report: 改了什么(目标/判据/路线,旧→新 + 为什么)/ 判据已重新盖章 ✅ / 旧版本已存档于 `.goal-driven/history/` / 继续方式:`/goal-driven:run`(会基于当前代码朝新判据继续)。**Do NOT auto-start the run** — revising is a deliberate human touchpoint; let the user launch when ready. Only if they explicitly say "revise and keep going" do you then `gdcc arm` + run.
