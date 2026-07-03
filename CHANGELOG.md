# Changelog

## 0.10.0 (2026-07-03)

Human-led co-design in loop A; cheap machine sanity check instead of heavy auto-audit.

- **The goal + criteria + roadmap are now co-designed WITH the human, in staged approval gates.**
  Rationale (control theory): those artifacts are the sensor + route of the loop and decide
  everything downstream, but a machine can only check whether criteria are *internally sound*
  (empty/cheat fail, coverage) — it CANNOT check whether they match what the human actually
  wants. Only the human validates **intent**. The old ratio was backwards (heavy designer↔auditor
  auto-loop, only 2–3 questions to the human); this flips it.
- **`/goal-driven:new` (and `:go`'s brand-new branch) rewritten as three gates** — Gate 1 GOAL →
  Gate 2 CRITERIA → Gate 3 技术路线 ROADMAP, each presented in 中文, edited, and **explicitly
  human-approved** before the next opens. **No 2–3 question cap** — ask whatever it takes.
- **WHAT vs HOW split — the human only ever approves the WHAT.** The human judges the goal, the
  *measurable acceptance conditions*, and the high-level route — all in plain language — and NEVER
  reviews the HOW (the `CRITERIA.sh` scripts / tests / baselines), because a human can't meaningfully
  audit bash/python and doesn't need to: the audit (see below) checks the script discriminates.
  Concretely, **Gate 2 is now spec-first** — `criteria-designer` first proposes a plain-language
  measurable acceptance table (no scripts) for the human to approve; only after approval does it
  implement `CRITERIA.sh` + baselines, which the audit — not the human — reviews. Saves tokens too
  (no scripts written until the semantic table is settled).
- **Audit is now a fast, advisory agent review by default; seal is instant and unconditional.**
  The old mechanical mutation battery re-ran the *full* CRITERIA.sh ×N (determinism + every baseline,
  each on a fresh project copy) — brutal when a criterion drives a real/HPC workload, and seal used to
  re-run the whole thing again. New model:
  - **`GDCC_AUDIT_LEVEL` (default `agent`)**: a read-only `criteria-auditor` subagent **statically
    reviews** CRITERIA.sh + baselines — reasons about whether empty/cheat would be rejected + coverage —
    **without executing** the workload. Fast, no project copy. Trades executed proof for speed (fine,
    since the human already validated intent). Levels `lite`/`full` still EXECUTE the baselines
    (opt-in, for cheap or high-stakes criteria); `off` skips review entirely.
  - The agent review is **advisory** — it reports concerns; the human decides to patch or accept. It
    never blocks.
  - **`gdcc seal` now does ONE thing: lock a tamper-evidence checksum.** No audit, no baseline-must-fail,
    always succeeds instantly. The checksum is what stops a worker silently rewriting the goalposts
    mid-run (even via Bash, which the edit-guard can't catch). Mechanical `lite`/`full` gained a
    `GDCC_AUDIT_EXCLUDE` knob for big data dirs.
- **Technical roadmap is co-designed upfront** and human-approved; at run time `goal-planner`
  **refines** that route instead of regenerating it (it stays unsealed — only goal/criteria freeze).
- **New brainstorm mode — get creative before giving up.** At a genuine dead-end the run no longer
  jumps to escalation. New agent **`goal-brainstormer` (fable)** does DIVERGENT ideation (invert the
  assumption, cross-domain analogy, change the dimension, exploit a contradiction, compose partial
  wins, remove the blocker), deduped against a `BRAINSTORM.md` log so each round is genuinely new.
  Stall ladder is now: re-plan → `goal-decider` VET → **brainstorm** → escalate. VET gained a
  **`BRAINSTORM`** verdict (stuck but not proven impossible) distinct from `ESCALATE` (provable wall);
  brainstorm runs up to `GDCC_BRAINSTORM_ROUNDS` (default 3) before escalating with everything creative
  attached. Manual trigger: **`/goal-driven:brainstorm`** to inject fresh ideas any time. fable
  allowlist now = planner, decider, brainstormer.
- **New `/goal-driven:revise` skill** — the sanctioned, auditable way to change a goal/criteria of
  an EXISTING task mid-run: re-walk the co-design gates but **grounded in current progress** (reads
  the live scoreboard + PROGRESS + ESCALATION), with deep human involvement. Backed by **new
  `gdcc revise-begin`** which snapshots the current GOAL/CRITERIA/ROADMAP into `.goal-driven/history/`
  (rollbackable), disarms + unseals, and logs the revision. The old goal is archived, never silently
  overwritten.

## 0.9.0 (2026-07-03)

Escalation escape valve + Fable-5 critical vetting at the Stop-gate.

- **No more "gate vs escalation" nagging.** When a criterion looks unreachable, the run no
  longer either loops forever or stops on the agent's own say-so. The Stop-gate now instructs:
  spawn `goal-decider` (model **fable**) to CRITICALLY vet the "unreachable" claim — hunting for
  contradictions (e.g. a weaker machine already beating the claimed floor → the bottleneck is
  the approach, not the hardware), untested assumptions, and untried angles.
- `VET: RESUME` → keep working the found angle (the claim was premature). `VET: ESCALATE` →
  `gdcc escalate "<vetted analysis>"` records `ESCALATION.md` and cleanly pauses for the human.
- **New `gdcc escalate "<reason>"`** — the only sanctioned pause-for-human: writes ESCALATION.md
  + trips the Stop-gate's escape valve. Agents may not stop/disarm on their own judgment.
- Fixed the Stop-gate message ([FAIL] wording) and made escalation a first-class, vetted stop.

## 0.8.0 (2026-07-02)

Proactive quota watch + headroom (there is no real-time quota).

- **`gdcc quota-watch`** — a background watcher (run via `Bash(run_in_background)`) that
  re-invokes the master the instant 5h usage >= the pause threshold, even mid-worker.
  On the event the master `TaskStop`s running workers, waits until reset, then resumes.
- **Headroom over precision** — the Anthropic usage API is ~5-min rate-limited, so no
  mechanism is truly real-time and none can preempt an in-flight model call. Default pause
  threshold lowered to **90%** (was 97%) to leave ~10% headroom for what a worker burns before
  the gate/watch catches it. A rate-limit that still slips through kills only the current
  worker subagent; the master catches it, waits until reset, and re-dispatches.
- Lighter review kept from 0.7.1: criteria changes default to `audit + seal`; panels are opt-in.

## 0.7.0 (2026-07-02)

One-shot autonomous entry point.

- **`/goal-driven:go <one-line goal>`** — the whole thing from one line: analyze →
  ask 2–3 clarifying questions (the ONLY interaction) → design + audit + seal
  criteria → arm → plan-execute-verify to completion. No manual `/goal-driven:run`
  step; after the upfront questions it never asks again (Stop gate + quota gate +
  goal-decider/reachability panel handle everything). Also resumes an existing task:
  sealed → straight to run; unsealed (e.g. a criterion under revision) → finish
  loop A (asking only the needed decision) then run.
- `/goal-driven:new` (build+stop for review) and `:run` (drive a sealed task) remain
  for granular control; `:go` is new+run chained.

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
