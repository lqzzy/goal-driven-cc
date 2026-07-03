---
description: Fully autonomous goal-driven run from one line — first co-design the goal, criteria & technical roadmap WITH the human (staged approval gates, the ONLY interaction), then light-check + seal, then plan-execute-verify to completion with no manual "run" step. Use when the user describes a goal and wants to walk away after getting the goal/criteria right — "just make it happen", "goal-driven this and run it to done", "auto run", "跑到完成别问我".
argument-hint: <one-line goal>
---

# /goal-driven:go — describe once, answer a few questions, walk away

Goal: **$ARGUMENTS**

Instructions in English; talk to the user in **简体中文**. The ONLY human interaction is the upfront **co-design** of the goal, criteria & technical roadmap — this is deliberately deep and interactive, because those artifacts decide everything and only the human can validate intent. After they are sealed, run to completion WITHOUT asking again — the Stop gate and quota gate enforce autonomy mechanically; forks are handled by `goal-decider`; a "criterion unreachable" claim goes to `goal-decider` (fable) critical vetting → `goal-brainstormer` (fable) for novel approaches → escalate only when even fresh ideas run dry.

## Phase A — reach sealed, trustworthy criteria
Run `gdcc status` first and branch on the state. **Questions are allowed ONLY when defining a brand-new goal; on any resume you decide everything yourself.**

- **Already sealed** → skip straight to Phase B.

- **Brand-new goal** (no `.goal-driven/`, or `GOAL.md` is still the empty template): this is the ONLY place you interact with the user, and here you go **deep** — run the **staged co-design exactly as `/goal-driven:new`**. No 2–3 question cap; ask whatever it takes to get intent right.
  1. `gdcc init`; recon the repo.
  2. **Gate 1 — GOAL:** `goal-analyst` drafts `GOAL.md` (verifiability gate: not auto-verifiable → report 中文, agree a proxy or stop) → present in 中文 → iterate → human approves.
  3. **Gate 2 — CRITERIA (approve WHAT, machine implements HOW):** `criteria-designer` (spec-first) proposes a plain-语言 **measurable acceptance table** (each requirement → condition/threshold + how decided; no scripts yet) → present in 中文 → iterate → human approves the table. THEN the designer implements `CRITERIA.sh` + tests + baselines (empty/cheat required, reference preferred) from the approved table — the human does NOT review that code; the agent audit vets it.
  4. **Gate 3 — 技术路线:** `goal-planner` (roadmap mode) drafts `ROADMAP.md` → present in 中文 → human reorders/approves the route.
  5. **Audit → seal:** spawn `criteria-auditor` (STATIC mode) — it READS CRITERIA.sh + baselines and judges whether empty/cheat would be rejected + coverage, **without executing** the workload (advisory: relay findings, the human decides to patch or accept) → `gdcc seal` (instant, unconditional — only locks the tamper checksum). Opt-in executed proof: set `GDCC_AUDIT_LEVEL=lite`/`full` and run `gdcc audit`. **No designer↔auditor loop.**

- **Resuming an existing but UNSEALED task** — resolve autonomously and CHEAPLY. **Right-size the review to the change; do not fire a multi-agent panel for a rule tweak.** A quick `criteria-auditor` (STATIC, read-only) review is the default sanity check — it reasons about whether the criteria are gameable/vacuous without executing them. So:
  1. Read `GOAL.md` / `CRITERIA.sh` / `PROGRESS.md` / `decisions.log` to see what changed and why.
  2. Pick the lightest sufficient path:
     - **Criteria only tightened/fixed, OR a relaxation already justified by recorded evidence** (GOAL.md / decisions.log) → straight to `gdcc seal`. **No reviewer, no panel.**
     - **A criterion is being relaxed as "unreachable" with NO recorded justification** → spawn **ONE** `reachability-reviewer` (opus, read-only) that **reads the existing evidence** to confirm the relaxation is justified and minimal — it does NOT re-run benchmarks unless there is genuinely no evidence at all. If justified, `goal-decider` (fable) finalizes the tightest intent-preserving criterion.
     - **Only** for a genuinely high-stakes relaxation with zero prior evidence → a full multi-`reachability-reviewer` re-derivation (opt-in, rare).
  3. `gdcc seal` (instant, unconditional). Append a one-line decision to `.goal-driven/decisions.log`. Proceed to Phase B.

## Phase B — run to completion (no manual step, no more questions)
6. `gdcc arm`. From here, do NOT call AskUserQuestion. Decide routine forks via `goal-decider`. If a criterion looks stuck/unreachable, do NOT decide it yourself: spawn `goal-decider` (model **fable**) to critically vet it (hunt for contradictions like weaker hardware outperforming, untested assumptions, untried angles) — `VET: RESUME` → keep working the angle; `VET: BRAINSTORM` (stuck, no ready angle, not proven impossible) → spawn `goal-brainstormer` (fable) for novel approaches, hand `TopPick`/`NextAction` to `goal-planner`, keep working; `VET: ESCALATE` (provably-impossible wall) → `gdcc escalate "<analysis>"`. Never stop/disarm on your own judgment.
7. **Run the staged loop exactly as `/goal-driven:run`:** `goal-planner` roadmap → for each phase { plan → `goal-worker` loop until the phase's target criteria pass → stall ladder: re-plan → VET → **brainstorm** (fable, novel approaches) → escalate only when brainstorm goes dry } → pass^k → `goal-verifier`. Apply the model matrix (fable only for planner, decider & brainstormer, everyone else ≤ opus, floor sonnet) and the quota logic (check `gdcc quota` before each worker; downgrade ≥80%; at ≥97% background-wait until reset then resume; the quota gate also halts work automatically).
8. **Finish:** on `GOAL VERIFICATION: ACHIEVED` → `gdcc disarm`, give a 中文 completion summary. On a criterion that looks unreachable → first vet via `goal-decider` (fable); `RESUME`/`BRAINSTORM` → keep working (brainstorm for fresh ideas before giving up); only when the wall is proven or brainstorm goes dry run `gdcc escalate` to pause for the human (the one allowed stop).

Emit a short 中文 status line at each stage transition so the user can watch if they want — but never block waiting for them after Phase A.
