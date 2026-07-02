# Changelog

## 0.6.0 (2026-07-02)

Preemptive quota gate + per-role model policy.

- **Quota gate (PreToolUse)** — `guard.sh` now checks 5h usage before EVERY action
  tool (Bash/Edit/Write/Task), including inside a running worker subagent. At/over
  `GDCC_QUOTA_PAUSE_AT` it denies the call, so work halts at its next tool call no
  matter what's running, and control returns to the master to wait-until-reset and
  resume. The master's own quota-control commands are allowlisted (no deadlock).
  Detection is bounded by claude-hud's ~5-minute cache refresh. Toggle `GDCC_QUOTA_GATE`.
- **Per-role model policy** — never haiku; fable 5 ONLY for goal-planner; non-planner
  ceiling = opus; floor = sonnet. Worker runs sonnet, escalates to opus on stall.
  Config: `GDCC_MODEL_PLANNER` / `GDCC_MODEL_STRONG` / `GDCC_MODEL_WORKER` / `GDCC_MODEL_LOW`.
- Quota checked before every worker dispatch (not just per phase).

## 0.5.0 (2026-07-02)

Quota-aware, fully in-conversation (headless dropped as the model).

- **Live quota readout** — `gdcc quota` reads claude-hud's usage cache
  (`~/.claude/plugins/claude-hud/.usage-cache.json`): plan, 5-hour utilization %,
  minutes-to-reset, 7-day %. Machine modes `gdcc quota pct|reset-secs|reset-epoch`.
  Shown in `gdcc status`. No-op if claude-hud isn't present.
- **Difficulty- & quota-aware model selection** — the run picks each subagent's
  model by role/difficulty (escalate on stall), and downgrades the worker to
  `GDCC_MODEL_LOW` when the 5h window is high (`GDCC_QUOTA_DOWNGRADE_AT`, default 80%).
- **Sleep-until-reset, in the conversation** — at the pause threshold
  (`GDCC_QUOTA_PAUSE_AT`, default 97%) the run starts a background wait
  (`until $(date +%s) >= $(gdcc quota reset-epoch)`) that re-invokes the agent when
  the window resets, then resumes — no terminal, no headless.
- **Headless de-emphasized** — `/goal-driven:run` is now the only documented path;
  everything (planning, execution, verification, quota waits) runs in the conversation.

## 0.4.0 (2026-07-02)

Staged, hierarchical planning (plan-execute-verify).

- **New `goal-planner` subagent** (8 agents total). Two modes: a coarse **ROADMAP** of ordered phases at the start of a run, and a just-in-time fine **PLAN** generated right before each phase (and on re-plan when a phase stalls).
- **`/goal-driven:run` is now a staged loop:** roadmap → for each phase { plan → goal-worker loop until the phase's target criteria pass → re-plan on stall } → pass^k → goal-verifier. Each phase's plan is written with the benefit of what earlier phases learned (PROGRESS), and each phase has an objective, criteria-mapped exit condition.
- `ROADMAP.md` + `PLAN.md` templates; `gdcc init` scaffolds them.

## 0.3.0 (2026-07-02)

In-conversation unattended autonomy (no terminal, no mid-run human prompts).

- **Unattended in-conversation runs.** `gdcc arm` now disables the `AskUserQuestion` tool for the project (writes `disallowedTools` to `.claude/settings.local.json`; `disarm` restores it) so the main agent literally cannot pause to ask — the reliable, platform-supported mechanism. (A hook cannot answer AskUserQuestion — Anthropic issue #12605 — so the earlier intercept-and-answer hook is now a log-only detector for leaked questions.) For immediate effect in a running session, launch with `claude --disallowedTools AskUserQuestion`.
- **Decide-yourself subagents:** when the agent hits a fork it spawns `goal-decider` (classifies ROUTINE vs GOAL-AFFECTING, answers routine ones per POLICY) and, for goal-affecting forks, a parallel `reachability-reviewer` panel that adversarially tests whether the goal is truly unreachable before it can ever be relaxed — only a strong-majority-unreachable verdict escalates to the human.
- **Goal integrity:** goal changes are never auto-applied — a strong-majority reachability panel must prove unreachability, and even then the loop ESCALATES rather than relaxing the goal. The `guard` now blocks edits to `GOAL.md`/`CRITERIA.sh`/`judge/` during a run, and the seal checksum now covers `GOAL.md` too.
- **POLICY.md** per task (pre-agreed answers to routine forks + the escalation bar); `gdcc init` scaffolds it.
- `/goal-driven:run` rewritten as the primary, in-conversation unattended loop; headless `gdcc run` demoted to optional.
- **Fix:** `gd_timeout` no longer hangs inside command substitution (a lingering watcher `sleep` was holding the capture pipe) — affected `gdcc judge`.

## 0.2.0 (2026-07-01)

Major workflow + reliability pass (ECC / Anthropic prompt-engineering study).

**Workflow moved into the conversation.** `/goal-driven:run` now makes the main agent the master: it runs the judge, dispatches `goal-worker` subagents on failure, verifies on success, and loops entirely in-session (no terminal). The headless `gdcc run` remains for long unattended runs.

**Judge is now a per-criterion scoreboard** so the master sees *why* it failed. `CRITERIA.sh` uses `check` (deterministic) and `soft` helpers.

**Soft criteria via `gdcc judge`** — a fresh, read-only, strict, independent LLM verifier for requirements that cannot be checked mechanically, composed into the exit-code contract.

**Sealing hardened.** `gdcc seal` now also verifies the criteria FAIL on the untouched code (rejects vacuous criteria) and locks a checksum of the judge surface. The Stop hook and `gdcc run` detect tampering with `CRITERIA.sh` and halt.

**Completion is pass^k** (`GDCC_CONSECUTIVE_PASSES`, default 2) — the criteria must pass k times in a row before the goal is declared met; then `goal-verifier` does a final anti-cheat + soft re-judge.

**New guards:** no-progress detection (repo tree unchanged N rounds), `GDCC_MAX_DURATION`, a PreToolUse guard that blocks `--no-verify` (and, in `strict` profile, force-push/hard-reset) during armed runs, and a stale-replay guard around injected PROGRESS.

**Prompt quality:** trigger-phrased agent descriptions; fenced output contracts (`GOAL VERIFICATION`, `CRITERIA AUDIT`); worker prompt de-negated (anti-cheat pushed to the mechanical layer); a worked BAD→GOOD example in criteria-designer.

**Model tiering is off by default** — every agent inherits the session model. Opt in via `model:` frontmatter or `GDCC_MODEL` / `GDCC_JUDGE_MODEL`.

## 0.1.0 (2026-07-01)

First release. Goal-Driven as a standard Claude Code plugin: loop-A criteria
construction (analyst / designer / auditor), the `gdcc audit` mutation battery,
loop-B worker loop + Stop-hook gate, `goal-worker` / `goal-verifier`, skills
`/goal-driven:new|run|status`, and the runnable `examples/is-prime` dogfood.
