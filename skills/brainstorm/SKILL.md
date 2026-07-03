---
description: Force a creative brainstorm on a stuck goal-driven task — spawn the fable goal-brainstormer to generate innovative, unconventional approaches when the run is grinding or you want to inject fresh ideas, instead of giving up or escalating. Use when the user says "brainstorm", "think outside the box", "we're stuck, get creative", "换个思路", "头脑风暴".
argument-hint: (optional: a hint / constraint / direction to bias the brainstorm)
---

# /goal-driven:brainstorm — inject creativity into a stuck run

Optional steer: **$ARGUMENTS**

This is the manual trigger for the same brainstorm the run uses automatically at a dead-end. It never changes the goal or criteria — it only finds **new routes to the SAME bar**. Instructions in English; talk to the user in **简体中文**.

## Steps
1. **Ground.** Run `gdcc status` / `gdcc check`. Read `.goal-driven/GOAL.md`, which criteria are `[FAIL]`, `PROGRESS.md`, `BRAINSTORM.md` (ideas already tried), and the relevant code/results. If there is no task, tell the user (中文) to set one up first (`/goal-driven:new`) and stop.
2. **Brainstorm.** Spawn `goal-brainstormer` (Task, model **fable**) with: the failing criteria + the stuck diagnosis (what's been tried and why it plateaued) + the user's optional steer. It appends new, deduped ideas to `BRAINSTORM.md` and returns its `BRAINSTORM` block (`TopPick` + `NextAction`, or `Dry: YES`).
3. **Act on it (简体中文):**
   - **Ideas produced** → present the ranked ideas + `TopPick` in 中文. If the task is armed/running, hand `TopPick`'s `NextAction` to `goal-planner` (re-plan for this phase) and continue the worker loop. If it's not running, offer to `/goal-driven:run` (or continue) with this direction.
   - **`Dry: YES`** (creative space exhausted) → tell the user plainly in 中文; if this is a genuine sanctioned dead-end, run `gdcc escalate` with a pointer to the full `BRAINSTORM.md` so the human decides with everything creative already on the table.
4. Log a one-line note to `.goal-driven/decisions.log`.

Brainstorm sits one rung below escalation: get creative FIRST, bother the human only when even fresh ideas run dry.
