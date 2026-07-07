---
description: Drive a sealed goal-driven task to completion IN THIS CONVERSATION, unattended — you become the master: run the judge, dispatch worker subagents on failure, verify on success, and loop until the criteria genuinely pass, without pausing to ask the human. Use after /goal-driven:new has sealed the criteria, when the user says "run it", "start the loop", "keep going until it's done", "run unattended".
argument-hint: (none)
---

# /goal-driven:run — in-conversation unattended master loop

You (the main agent) are the **master**. The whole loop runs **in this conversation** — this is the intended mode; do not tell the user to open a terminal. Instructions in English; talk to the user in **简体中文**.

## Preconditions
Run `gdcc status`. If there is no task, or criteria are **not sealed**, tell the user (中文) to run `/goal-driven:new` first, and stop. Never bypass the seal.

## Arm (mechanically enforce unattended)
Run `gdcc arm`. This closes both human-pause channels by mechanism:
- **Stop gate** — re-runs the judge if you try to end your turn; blocks stopping until the criteria pass (pass^k).
- **AskUserQuestion disabled** — `arm` writes `disallowedTools: [AskUserQuestion]` into the project's `.claude/settings.local.json`, so the tool is not available and you cannot pause to ask.
  - This takes effect at session start. If AskUserQuestion is still callable in the current session, tell the user (中文) to relaunch with `claude --disallowedTools AskUserQuestion` and re-run this skill for a guaranteed unattended run; a question that slips through is logged to `.goal-driven/decisions.log`.

## The staged plan-execute loop (unattended)
**Every planning step is brainstorm → plan.** Before the planner runs, a divergent `goal-brainstormer` (fable) proposes the best / fastest / most robust routes; then `goal-planner` (fable) evaluates those options and commits the plan. Diverge before you converge — never let the planner settle for the first obvious route.

1. **Roadmap (once).**
   a. Spawn `goal-brainstormer` (Task, **fable**, pre-plan mode) with GOAL + CRITERIA → 2–4 genuinely distinct overall routes to all-green (different decompositions / orderings / strategies) with trade-offs.
   b. Spawn `goal-planner` (Task, **fable**, roadmap mode) with those options → it picks/synthesizes the strongest and writes `.goal-driven/ROADMAP.md`: a small ordered set of phases, each with its target criteria + exit condition.
2. **For each phase, in order:**
   a. **Plan (brainstorm → plan, just-in-time).** Spawn `goal-brainstormer` (fable, pre-plan mode) for THIS phase (its target criteria + what's done) → distinct approaches for the phase; then spawn `goal-planner` (fable) → it evaluates them and writes `.goal-driven/PLAN.md` (fine steps + the phase's exit condition). Append "entering phase N" to PROGRESS.md.
   b. **Execute + verify.** Loop:
      1. Spawn a `goal-worker` (Task) with PLAN.md + the current `[FAIL]` criteria (from `.goal-driven/verdict.txt`) → it makes the smallest real change and self-checks its own work.
      2. **Verify:** spawn the `strict-verifier` (Task) → it scores `CRITERIA.md` against the actual artifacts, writes `verdict.txt`, and runs `gdcc verdict record` (which stamps `verdict.json` with the code's tree hash + all_pass + pass^k streak). Read the result with `gdcc check`.
      Repeat until the phase's **exit condition** holds (its target criteria are `[PASS]`). If a subagent dies from a transient API error, spawn another (POLICY: up to 3). Worker + verifier are subagents with their own context, so your master context grows slowly.
      - **Dispatch synchronously — this is the default and what the Stop gate assumes.** Spawn worker and verifier as **blocking** Tasks (`run_in_background: false`) and wait for each to return. Do NOT background the worker: if you yield the turn mid-work the Stop gate would see a stale verdict and push a duplicate dispatch. Background dispatch is only for the quota waits/watch below.
      - **If you must background a worker** (e.g. a very long build/benchmark you want to leave the master free during), bracket it: `gdcc worker begin <id>` right before you background it, `gdcc worker end <id>` the moment it returns (on the completion notification). While a marker is live the Stop gate **defers** (lets you rest until the worker wakes you) instead of blocking or re-dispatching; a crashed worker's marker expires on its own (`GDCC_WORKER_TTL`).
   c. **Stall ladder — get creative before giving up.** If several worker turns make no real progress (same `[FAIL]`, unchanged code):
      1. **Re-plan** — spawn `goal-planner` for this phase WITH the stall diagnosis, resume (b). Cheap; handles most stalls. Cap re-plans per phase.
      2. **Re-plan exhausted → `goal-decider` (fable) VET** — is it really stuck? `RESUME` (it found an angle) → work it. `ESCALATE` (a genuinely, provably-impossible wall) → `gdcc escalate`. `BRAINSTORM` (stuck, no ready angle, but NOT proven impossible) → step 3.
      3. **Brainstorm (rescue mode)** — spawn `goal-brainstormer` (Task, model **fable**, rescue mode) with the failing criteria + what's been tried (it dedups against `BRAINSTORM.md`). It returns novel approaches: hand its `TopPick`/`NextAction` to `goal-planner` (re-plan) and resume (b). Repeat up to `GDCC_BRAINSTORM_ROUNDS` (default 3) as long as it keeps producing genuinely new ideas.
      4. **Brainstorm dry / rounds exhausted** (`Dry: YES`, or the cap is hit with no progress) → NOW `gdcc escalate` with a pointer to `BRAINSTORM.md` — the human decides with every creative angle already tried. Escalation is the last rung, never the first.
   d. Advance to the next phase.
3. **All phases done → confirm & verify.** Re-run the `strict-verifier` until `gdcc check` reports **fresh, all-pass, with streak ≥ GDCC_CONSECUTIVE_PASSES** (pass^k); if anything is `[FAIL]` or STALE, return to the relevant phase. Then spawn `goal-verifier` (Task, independent) for the final anti-cheat sweep + an independent re-judge of `CRITERIA.md`. `GOAL VERIFICATION: ACHIEVED` → `gdcc disarm`, 中文 completion summary, stop. `PARTIAL`/`FAILED` → treat its `Next:` items as a mini-phase (plan → work), continue.

## Model & quota — checked before EVERY worker dispatch (all in-conversation)
Right before you spawn each `goal-worker` (and each planner/verifier), read `gdcc quota pct` (claude-hud's live 5-hour utilization %) and set the subagent's `model` on the Task call per this matrix:

| role | normal | on stall / re-plan | quota ≥ downgrade | ceiling |
|---|---|---|---|---|
| goal-planner / goal-decider / goal-brainstormer | **fable** | — | opus → sonnet | fable |
| reachability-reviewer / strict-verifier / goal-verifier / criteria-designer / goal-analyst | opus | — | sonnet | opus |
| goal-worker | sonnet | opus | sonnet | opus |

**Hard rules: never haiku; fable ONLY for goal-planner, goal-decider, and goal-brainstormer; everyone else ceiling = opus; floor = sonnet.** (Values: `GDCC_MODEL_DECISION` / `GDCC_MODEL_STRONG` / `GDCC_MODEL_WORKER` / `GDCC_MODEL_LOW`.)

Quota thresholds (from `gdcc quota pct`):
- **≥ `GDCC_QUOTA_DOWNGRADE_AT` (default 80%)** → apply the "quota ≥ downgrade" column.
- **≥ `GDCC_QUOTA_PAUSE_AT` (default 97%)** → wait until the window resets, in this conversation: start a background wait that exits at reset time and re-invokes you, then resume:
  ```
  Bash(run_in_background: true,
       command: "until [ \"$(date +%s)\" -ge \"$(gdcc quota reset-epoch)\" ]; do sleep 120; done; echo quota-window-reset")
  ```
  Tell the user (中文) you're pausing until the reset time. When it completes you are re-invoked automatically → re-check `gdcc quota` and continue. (All in the conversation — no terminal; needs the session to stay open.)
- **Automatic interrupt (don't rely only on the per-dispatch check):** a PreToolUse **quota-gate** runs before EVERY action tool — including inside a running `goal-worker`. The moment 5h usage ≥ the pause threshold it denies further tool calls, so work halts at the next tool call no matter what's running, and control returns to you. When you (or a worker) hit a `quota-gate` denial, immediately launch the background wait-until-reset above and resume after it fires.
- **Proactive background watch:** at the START of the run, launch
  ```
  Bash(run_in_background: true, command: "gdcc quota-watch")
  ```
  It polls in the background and exits — re-invoking you — the instant 5h usage ≥ the pause threshold, even while a worker is mid-run. On that `QUOTA_CEILING_HIT` event: **`TaskStop` any running worker subagents**, then start the wait-until-reset background loop; after reset, relaunch `gdcc quota-watch` and resume.
- **Honest limits (why headroom matters):** usage data is only ~5-minutes fresh (the Anthropic usage API is rate-limited — there is NO real-time quota, and polling faster just returns the same number), and neither the gate nor the watch can preempt an already-in-flight model call — the halt/kill lands at the next step. So the real protection is **margin**: pause at 90% (not 97%), leaving ~10% headroom for whatever a worker consumes before the gate/watch catches it. Raise/lower `GDCC_QUOTA_PAUSE_AT` to trade safety vs. wasted quota. A rate-limit that still slips through kills only the current worker subagent — catch it, wait-until-reset, and re-dispatch; treat it as pause-and-retry, not task failure.

## Autonomy rules (this is the point of the project)
You cannot ask the human (the tool is disabled). When you hit a fork, decide it yourself via subagents:
1. Spawn the `goal-decider` subagent (Task) with the fork + options. It returns `Class: ROUTINE | GOAL-AFFECTING` + a `Choice`.
2. **ROUTINE** → follow the `Choice` per `.goal-driven/POLICY.md`, note it in PROGRESS.md, keep working.
3. **GOAL-AFFECTING** (would relax/drop/edit the goal, or a criterion looks unreachable/stuck) → spawn `goal-decider` (model **fable**) to CRITICALLY vet it — it hunts for contradictions (e.g. a weaker machine/config already outperforming the claimed floor, results that violate scaling), untested assumptions, and untried angles. Read its `VET` block: **RESUME** → the claim was premature; keep working on its `NextAngle`, do NOT change the goal. **BRAINSTORM** → it's stuck with no ready angle but not proven impossible: spawn `goal-brainstormer` (fable) for novel approaches → hand its `TopPick`/`NextAction` to `goal-planner` and keep working; only when brainstorm goes `Dry: YES` (or `GDCC_BRAINSTORM_ROUNDS` is hit) do you escalate. **ESCALATE** → a genuinely, provably-impossible wall: run `gdcc escalate "<the VET ForHuman analysis + the decision needed>"` — records `ESCALATION.md` and cleanly pauses for the human. If the decider needs hard benchmark evidence, it may have you run a `reachability-reviewer` panel (opus) first. **Never stop or disarm on your own judgment — escalate ONLY via `gdcc escalate`, and only after brainstorm is exhausted or the wall is proven.**
- **Never change/relax the goal or criteria**, and never edit `GOAL.md`/`CRITERIA.md` (the guard blocks it; the seal checksum catches it).
- Log every self-decision to `.goal-driven/decisions.log`; escalations to `ESCALATION.md`. The user can interrupt any time; `gdcc stop` ends the loop cleanly.

## Everything stays in this conversation
There is no terminal/headless step. You (the main agent) drive the whole loop here, using Task subagents (planner/worker/verifier), `gdcc check`/`quota`, and in-conversation background waits for quota resets. If you ever try to end the turn before the goal is genuinely met, the Stop gate blocks you and feeds back what's still failing.
