<div align="center">

# ◉ Goal-Driven for Claude Code

**Give it a one-line goal. Get a result that's actually met.**

A Claude Code plugin that turns coding into a **closed control loop**: you define the goal and verifiable criteria, a master agent supervises worker agents in a negative-feedback loop until the criteria *genuinely* pass — right in the conversation, no babysitting.

<br/>

[![version](https://img.shields.io/badge/version-0.11.0-2563eb?style=flat-square)](./CHANGELOG.md)
[![license](https://img.shields.io/badge/license-MIT-16a34a?style=flat-square)](./LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-8b5cf6?style=flat-square)](https://docs.claude.com/en/docs/claude-code)
[![status](https://img.shields.io/badge/status-alpha-f59e0b?style=flat-square)](#-roadmap)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-ec4899?style=flat-square)](#-contributing)

<br/>

[**Quick start**](#-install) · [**Why**](#-what-it-solves) · [**How it works**](#-how-it-works) · [**Commands**](#-commands) · [**Config**](#️-configuration)

</div>

---

```text
you ▸ /goal-driven:go  implement an LRU cache that passes all unit tests

CC  ▸ ① co-design goal · criteria · plan with you   →  ✅ sealed
      ② run unattended:  worker → gdcc check → C1 ✓  C2 ✗  C3 ✗ → keep going
         · brainstorms before it gives up · waits out quota limits ·
      ③ ✅ GOAL VERIFICATION: ACHIEVED  —  green twice in a row, wrapped up on its own
```

<br/>

## ✨ Why use it

|  |  |
|---|---|
| 🎯 **One line → verifiable criteria** | Nail the goal with it, then it derives a plain-language `CRITERIA.md` acceptance bar you read and approve directly. A fresh, independent **strict-verifier** judges the work against it every iteration. |
| 🔁 **Unattended, in the conversation** | The main agent becomes the master: dispatches workers, runs the criteria, keeps going on failure. **No terminal**, and a Stop-gate won't let it quit early. |
| 🛡️ **Reward-hacking resistant** | An independent strict-verifier judges only concrete evidence — it won't pass a stub or a shortcut, and its verdict is void the moment the code changes. Sealing locks a checksum, so a worker can't quietly move the goalposts mid-run. |
| 🧠 **Doesn't give up** | At a dead-end it first has `goal-decider` critically vet the "stuck" claim, then `goal-brainstormer` (fable 5) generates fresh approaches — it escalates to you only once creative options run dry. |
| 🔋 **Quota-aware** | Reads claude-hud usage: downgrades the model when high, waits out the window at the ceiling — all in-conversation. |
| 🧩 **Standard plugin** | One command to install. 6 slash commands, 9 specialized sub-agents, zero config. |

<br/>

## 🚀 Install

> Requires [Claude Code](https://docs.claude.com/en/docs/claude-code). In Claude Code, run:

```bash
/plugin marketplace add lqzzy/goal-driven-cc
/plugin install goal-driven@goal-driven-cc
```

Ready to use — no extra setup.

<br/>

## 🧭 Quick start

**The easy path** — describe a goal, answer a few questions, then walk away:

```bash
/goal-driven:go refactor src/parser until every test in tests/ passes with no lint errors
```

Prefer step-by-step control? Split it in two:

```bash
/goal-driven:new  <goal>   # co-design goal / criteria / tech plan with you → seal (stops for you to launch)
/goal-driven:run           # drive it unattended until the criteria are genuinely green
```

<br/>

## 🎯 What it solves

Typical agent loops have two chronic problems:

1. **They need babysitting** — you keep coming back to confirm and click *continue*.
2. **They reward-hack** — to "make the tests green" they may hardcode, weaken checks, or game the goal.

**Goal-Driven** treats coding as a **closed-loop control system**:

- **Criteria = sensor** — objectively measure *"is the goal met?"*
- **Master (the main agent) = controller** — reads the error, dispatches work, never stops early.
- **Worker (sub-agent) = actuator** — reads what's failing, makes the smallest real change.

Your one job: **get the goal and criteria right up front, together with it.** After that the loop converges on its own — that's what *goal-driven* means.

<br/>

## 🔁 How it works

Two nested loops: **Loop A** turns the goal into trustworthy criteria (co-designed with you); **Loop B** drives to all-green (unattended).

```mermaid
flowchart TB
    G["🗣️ one-line goal"] --> A

    subgraph A["Loop A · agree the goalposts — you approve GOAL + CRITERIA.md"]
        direction TB
        A1["Gate 1 · GOAL"] --> A2["Gate 2 · CRITERIA.md (you read & approve)"]
        A2 --> AU["seal 🔒 (lock checksum)"]
    end

    A --> B

    subgraph B["Loop B · unattended execution — in the conversation"]
        direction TB
        B0["brainstorm → plan (roadmap, then each phase)"] --> B2["worker iterates"]
        B2 --> BV["strict-verifier → verdict"] --> B3{"all green?"}
        B3 -- no --> B4["stuck ladder: re-plan → VET → brainstorm → escalate"]
        B4 --> B2
        B3 -- yes --> B5["pass^k + independent final check ✅"]
    end

    B5 --> DONE["🎉 goal met"]
```

**The stuck ladder** — it gets creative before giving up; escalating to you is the *last* rung:

```text
worker keeps failing
  → re-plan             cheap; clears most stalls
  → goal-decider · VET  fable, skeptical: is it really stuck? any missed contradiction / angle?
  → goal-brainstormer   fable, divergent: invert the assumption · cross-domain analogy · change the axis…
  → ideas run dry → gdcc escalate → over to you, with "everything creative we tried" attached
```

<br/>

## 🧩 Commands

| Command | What it does |
|---|---|
| `/goal-driven:go <goal>` | **One shot**: co-design criteria → seal → run to completion, unattended. The daily driver. |
| `/goal-driven:new <goal>` | Co-design and seal the criteria only, then stop for you to launch. |
| `/goal-driven:run` | Drive a sealed task unattended until every criterion is green. |
| `/goal-driven:revise` | Re-define the goal / criteria / plan grounded in current progress (old version archived). |
| `/goal-driven:brainstorm` | Manually inject creativity into a stuck task. |
| `/goal-driven:status` | Progress, criteria scoreboard, seal & quota status. |

<br/>

## 🛡️ Design principles

- **You own the goalposts; the machine drives to them.** You approve the goal and read + approve `CRITERIA.md` — a plain-language acceptance bar, no bash to audit. From there the loop plans, works, and verifies on its own.
- **The sensor is a fresh, independent verifier.** Every iteration a read-only strict-verifier judges `CRITERIA.md` against the actual artifacts — it takes nobody's word, and its verdict is void the instant the code changes (tree-hash stamped). The Stop gate only reads that cached verdict; it never runs an LLM itself (that would fork-bomb the hook).
- **Sealing stops goalpost-moving.** Sealing just locks a `GOAL.md` + `CRITERIA.md` checksum (instant). While armed the guard blocks edits, and the checksum catches the one gap it can't — a worker rewriting the goalposts through Bash.
- **It never silently relaxes the goal.** An agent can't change the criteria on its own. To change them you go through `revise` (human-authorized, archived, auditable), or — at a true dead-end — it escalates to you after a fable review.

<br/>

## ⚙️ Configuration

Per task, in `.goal-driven/config.env` (sensible defaults — you rarely touch these):

| Variable | Default | What it does |
|---|---|---|
| `GDCC_CONSECUTIVE_PASSES` | `2` | Strict-verifier must return all-pass this many times in a row, on the same code, to count as met (pass^k, beats a flaky/lucky verification). |
| `GDCC_QUOTA_PAUSE_AT` | `90` | 5h-usage % at which the run pauses and waits for the window to reset (headroom for in-flight calls). |
| `GDCC_QUOTA_DOWNGRADE_AT` | `80` | Usage % at which the worker drops to a cheaper model. |
| `GDCC_BRAINSTORM_ROUNDS` | `3` | Auto-brainstorm rounds at a dead-end before escalating to you. |
| `GDCC_MODEL_*` | — | Per-role models: fable only for planner / decider / brainstormer; everyone else caps at opus, floors at sonnet, never haiku. |

<br/>

## ❓ FAQ

<details>
<summary><b>Will it cheat just to turn the criteria green?</b></summary>
<br/>
That's the whole point of the project. Every iteration a fresh, independent <b>strict-verifier</b> judges the work against <code>CRITERIA.md</code> from concrete evidence — it won't accept a stub, a hardcoded output, or an altered frozen input, and its verdict goes stale the instant the code changes. After sealing, the <code>GOAL.md</code> + <code>CRITERIA.md</code> checksum is locked, so a worker rewriting the goalposts mid-run is caught and halts the loop. You own whether the criteria match your intent (you read and approve them); the strict-verifier owns whether the work actually meets them.
</details>

<details>
<summary><b>Will it run forever and burn all my quota?</b></summary>
<br/>
No runaway. It reads claude-hud's usage cache: downgrades the model when high, and at the pause threshold (default 90%) waits in the background for the window to reset before resuming — all in the conversation. Usage data refreshes ~every 5 minutes (API limit), so the strategy is <i>headroom</i>, not pinpoint timing.
</details>

<details>
<summary><b>What if the goal really can't be reached?</b></summary>
<br/>
It won't give up at the first setback, and it won't quietly relax the goal. At a dead-end, fable first critically vets the "stuck" claim (often finding a missed angle to keep going), then fable brainstorms novel approaches; <b>only once ideas are exhausted</b> does it <code>gdcc escalate</code> — handing you a full analysis to decide on.
</details>

<details>
<summary><b>Do I need a terminal open the whole time?</b></summary>
<br/>
No terminal. The entire loop runs inside the Claude Code conversation (the main agent spawns Task sub-agents). Just keep the session open; for long unattended runs, <code>/clear</code> first or start a clean session with <code>claude --disallowedTools AskUserQuestion</code>.
</details>

<br/>

## 🗺️ Roadmap

Goal-Driven is **alpha** — the core loop works today. Where it's headed:

**Next**
- 📚 **Criteria presets** — starter templates for common goals (tests-pass, perf budget, safe refactor, API contract) so you jump straight to review.
- 🧵 **Parallel goals** — run and supervise several sealed goals at once.
- 💾 **Resumable runs** — checkpoint a run and pick it up in a fresh session.

**Exploring**
- 📊 A live run dashboard — phases, scoreboard, token spend at a glance.
- 🤖 CI mode — drive a goal to green as a GitHub Action.
- 🔬 Self-mutation testing of the code under test, not just the criteria.

Driving a goal we don't cover yet? [Open an issue](../../issues) — the roadmap follows what people actually build.

<br/>

## 🤝 Contributing

Issues and PRs welcome. Include how you verified your change; for criteria changes, make each criterion sharp and evidence-based so a stub can't pass it.

## 📄 License

[MIT](./LICENSE) © Qi Li

<div align="center"><sub>Control theory, turning goals into results.</sub></div>
