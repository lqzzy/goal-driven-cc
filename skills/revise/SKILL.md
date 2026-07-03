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
- `.goal-driven/GOAL.md`, `CRITERIA.sh`, `ROADMAP.md` — the current contract + route.
- **Live scoreboard:** run `gdcc check` — which criteria are `[PASS]` / `[FAIL]` right now.
- `PROGRESS.md`, `decisions.log`, `ESCALATION.md` (if present), `audit-report.md` — what was tried, what was learned, what's stuck and why.
- The relevant code/results/benchmarks, so a claim like "C2 is unreachable" is checked against evidence, not taken at face value.

Present a short 简体中文 **current-state briefing**: 当前目标一句话 / 判据现状(过了哪几条、卡在哪条、为什么)/ 已学到的关键事实 / 这次想改什么。The human decides with full knowledge of where things stand.

## Step 2 — enter revise mode (snapshot + unlock)
Run `gdcc revise-begin "<one-line why>"`. It snapshots the current GOAL/CRITERIA/ROADMAP (+judge) into `.goal-driven/history/` (auditable + rollbackable), disarms (the guard goes inert so edits are allowed), unseals (unlocks the checksum), and logs the revision start to `decisions.log`. **The old goal is archived, never silently overwritten.**

## Step 3 — staged approval gates, seeded with progress (same rigor as `/goal-driven:new`)
Re-run the three gates, but each draft is a **revision** of the current artifact informed by Step 1 — not a blank redo. Present in 简体中文, iterate, and advance ONLY on the human's explicit approval. **The human approves only the WHAT** (goal, measurable acceptance conditions, high-level route — all plain language); they never review the HOW (the `CRITERIA.sh` / test / baseline code), which the audit (a `criteria-auditor` static review by default) vets.

**Gate 1 — GOAL.** Spawn `goal-analyst` (Task) with the current GOAL.md + the progress briefing + the human's revise intent. It proposes a **revised** GOAL: keep what still holds, change what the evidence/human says to change, and call out exactly what moved and why. The verifiability gate still applies. Iterate → approve.

**Gate 2 — CRITERIA (approve the WHAT, then the machine re-implements the HOW).**
- **2a — agree the revised measurable acceptance conditions.** Spawn `criteria-designer` (Task, spec-first) → it proposes, in plain 简体中文, the **revised acceptance table** (each GOAL requirement → measurable condition/threshold + how decided), showing **old→new** for what changed and **preserving conditions that still hold** (don't churn passing ones). No scripts yet. Guard against "relaxing a condition just to turn red green": every change must trace to a GOAL change the human approved. Iterate on thresholds → human approves the table.
- **2b — re-implement + mechanically audit (machine-only).** The designer turns the approved table into `CRITERIA.sh` + tests + baselines (keeping still-correct checks intact). The human does NOT review this code — the audit in Step 4 vets it. Bounce back only on a NEW semantic question.

**Gate 3 — 技术路线 ROADMAP.** Spawn `goal-planner` (Task, roadmap mode) → revises the route given current progress (what's already done stays done; re-sequence the rest). Present → human approves.

## Step 4 — audit → re-seal (only after the human is satisfied)
Same as `new`; the human already owns intent.
- **a. Audit (default = agent static review; advisory).** Spawn `criteria-auditor` (Task, STATIC mode) → it READS the revised GOAL + CRITERIA.sh + baselines and judges whether the empty/cheat baselines would be rejected + coverage, **without executing** the workload. Relay its verdict in 简体中文; if it flags a broken/gameable check (e.g. a criterion relaxed until a cheat now passes) or a coverage gap, the human decides — patch via `criteria-designer` or accept. It never blocks the re-seal. (Opt-in executed proof: set `GDCC_AUDIT_LEVEL=lite`/`full` and run `gdcc audit` — lite executes empty+cheat must-FAIL; use it when the revised `CRITERIA.sh` is cheap to run.)
- **b. Re-seal (instant, unconditional).** Run `gdcc seal` — it runs no audit and always locks the new checksum. If the revised goal is already met by the work built so far, that's fine: `/goal-driven:run` will just verify (pass^k + goal-verifier) and finish.
- Append a one-line old→new summary to `.goal-driven/decisions.log`.

## Step 5 — hand off (简体中文)
Report: 改了什么(目标/判据/路线,旧→新 + 为什么)/ 判据已重新盖章 ✅ / 旧版本已存档于 `.goal-driven/history/` / 继续方式:`/goal-driven:run`(会基于当前代码朝新判据继续)。**Do NOT auto-start the run** — revising is a deliberate human touchpoint; let the user launch when ready. Only if they explicitly say "revise and keep going" do you then `gdcc arm` + run.
