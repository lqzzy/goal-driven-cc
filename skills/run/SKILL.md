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
1. **Roadmap (once).** Spawn `goal-planner` (Task, roadmap mode) → it writes `.goal-driven/ROADMAP.md`: a small ordered set of phases, each with its target criteria and an exit condition.
2. **For each phase, in order:**
   a. **Plan (just-in-time).** Spawn `goal-planner` (Task) for THIS phase → it writes `.goal-driven/PLAN.md` (fine steps + the phase's exit condition). Append "entering phase N" to PROGRESS.md.
   b. **Execute.** Loop: spawn a `goal-worker` (Task) with PLAN.md + the current `[FAIL]` criteria; then `gdcc check`. Repeat until the phase's **exit condition** holds (its target criteria are `[PASS]`). If a worker dies from a transient API error, spawn another (POLICY: up to 3). Workers are subagents with their own context, so your master context grows slowly.
   c. **Stall → re-plan.** If several worker turns make no real progress (same `[FAIL]`, unchanged code), spawn `goal-planner` again for this phase WITH the stall diagnosis (re-plan), then resume (b). Cap re-plans per phase; if still stuck, treat it as a goal-affecting fork → run the reachability panel (see Autonomy rules).
   d. Advance to the next phase.
3. **All phases done → confirm & verify.** Run `gdcc check` until it passes **GDCC_CONSECUTIVE_PASSES times in a row** (pass^k); if any `[FAIL]`, return to the relevant phase. Then spawn `goal-verifier` (Task, independent) for the final anti-cheat + soft re-judge. `GOAL VERIFICATION: ACHIEVED` → `gdcc disarm`, give a 中文 completion summary, stop. `PARTIAL`/`FAILED` → treat its `Next:` items as a mini-phase (plan → work), continue.

## Model & quota — checked before EVERY worker dispatch (all in-conversation)
Right before you spawn each `goal-worker` (and each planner/verifier), read `gdcc quota pct` (claude-hud's live 5-hour utilization %) and set the subagent's `model` on the Task call per this matrix:

| role | normal | on stall / re-plan | quota ≥ downgrade | ceiling |
|---|---|---|---|---|
| goal-planner | **fable** | — | opus → sonnet | fable |
| auditor / verifier / designer / analyst / decider / reviewer | opus | — | sonnet | opus |
| goal-worker | sonnet | opus | sonnet | opus |

**Hard rules: never haiku; fable ONLY for the planner; non-planner ceiling = opus; floor = sonnet.** (Values: `GDCC_MODEL_PLANNER` / `GDCC_MODEL_STRONG` / `GDCC_MODEL_WORKER` / `GDCC_MODEL_LOW`.)

Quota thresholds (from `gdcc quota pct`):
- **≥ `GDCC_QUOTA_DOWNGRADE_AT` (default 80%)** → apply the "quota ≥ downgrade" column.
- **≥ `GDCC_QUOTA_PAUSE_AT` (default 97%)** → wait until the window resets, in this conversation: start a background wait that exits at reset time and re-invokes you, then resume:
  ```
  Bash(run_in_background: true,
       command: "until [ \"$(date +%s)\" -ge \"$(gdcc quota reset-epoch)\" ]; do sleep 120; done; echo quota-window-reset")
  ```
  Tell the user (中文) you're pausing until the reset time. When it completes you are re-invoked automatically → re-check `gdcc quota` and continue. (All in the conversation — no terminal; needs the session to stay open.)
- **Automatic interrupt (don't rely only on the per-dispatch check):** a PreToolUse **quota-gate** runs before EVERY action tool — including inside a running `goal-worker`. The moment 5h usage ≥ the pause threshold it denies further tool calls, so work halts at the next tool call no matter what's running, and control returns to you. When you (or a worker) hit a `quota-gate` denial, immediately launch the background wait-until-reset above and resume after it fires. (Detection latency is bounded by claude-hud's ~5-minute cache refresh — the usage API can't be polled faster.)

## Autonomy rules (this is the point of the project)
You cannot ask the human (the tool is disabled). When you hit a fork, decide it yourself via subagents:
1. Spawn the `goal-decider` subagent (Task) with the fork + options. It returns `Class: ROUTINE | GOAL-AFFECTING` + a `Choice`.
2. **ROUTINE** → follow the `Choice` per `.goal-driven/POLICY.md`, note it in PROGRESS.md, keep working.
3. **GOAL-AFFECTING** (would relax/drop/edit the goal or criteria, or claim it's unreachable) → spawn `GDCC_PANEL_SIZE` (default 3) `reachability-reviewer` subagents **in parallel** (one message, N Task calls). Tally their `VERDICT` lines: strong-majority **REACHABLE** → do NOT change the goal, keep working on the approach they named; strong-majority **UNREACHABLE** → append evidence to `.goal-driven/ESCALATION.md` and stop for the human — this is the one legitimate human touchpoint.
- **Never change/relax the goal or criteria**, and never edit `GOAL.md`/`CRITERIA.sh` (the guard blocks it; the seal checksum catches it).
- Log every self-decision to `.goal-driven/decisions.log`; escalations to `ESCALATION.md`. The user can interrupt any time; `gdcc stop` ends the loop cleanly.

## Everything stays in this conversation
There is no terminal/headless step. You (the main agent) drive the whole loop here, using Task subagents (planner/worker/verifier), `gdcc check`/`quota`, and in-conversation background waits for quota resets. If you ever try to end the turn before the goal is genuinely met, the Stop gate blocks you and feeds back what's still failing.
