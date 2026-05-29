# Run Management (Simplified)

> **Status**: Designed (pending /design-review)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Pillar 1 (Every Run Tells a Different Story)

## Overview

Run Management is the lifecycle owner of a single run in The Last Cipher. It initializes run data when a run begins (`run_started`), tracks each wave result as the encounter progresses (`wave_ended`), and finalizes the run record when the run ends (`run_ended`) — whether through victory or Fayde's death. At MVP simplified scope, run management is intentionally minimal: a run is one arena, one encounter, and the only state that carries between start and end is whether the player won or lost. There is no loot tracking, no meta-currency accumulation, and no persistent progression between runs. Players experience this system through its outputs — the Run Summary Screen (win) and Death Screen (loss) that conclude every run — not through any direct interaction. The system exists to make a "run" a coherent, bounded unit that Game State & Scene Flow can start, track, and end cleanly.

## Player Fantasy

Run Management is infrastructure — players do not experience the system, they experience what it enables.

**The complete run** — every session has a clear arc: beginning (Fayde enters the arena), middle (the encounter tests the prepared grid), end (win or die). This system makes that arc coherent. The game never leaves Fayde in an ambiguous state — when the last enemy falls, the run is over; when Fayde dies, the run is over. There is no lingering.

**Legible failure (Pillar 3)** — the Death Screen reflects what happened this run. At MVP: a clear signal that Fayde is gone and a new run is immediately available. Players experience the run as a *unit of learning*, not a punishment.

**The instant restart** — players who want to try again feel no friction between run end and run begin. Run Management ensures the clean handoff: run state finalized, data ready for the Summary Screen, system reset for the next attempt.

*The above fantasy is delivered through Run Summary Screen (#23) and the Death Screen (owned by Game State & Scene Flow). Run Management provides the data those systems display.*

*`creative-director` not consulted — lean mode. Review manually before production.*

## Detailed Design

### Core Rules

1. `RunManager` is a GDScript Autoload singleton registered in Project Settings → AutoLoad **after** `GameStateManager`. Globally accessible as `RunManager`.

2. `RunManager` maintains a minimal run record with exactly three fields at MVP scope:
   - `run_active: bool` — whether a run is currently in progress
   - `run_outcome: RunOutcome` (enum: `NONE` / `WIN` / `LOSS`) — result of the most recent run
   - `waves_completed: int` — count of `COMBAT_PHASE → PREPARATION_PHASE` cycles this run (inter-wave returns)

3. `RunManager` connects to `GameStateManager` signals at `_ready()`: `run_started`, `wave_ended`, `room_cleared`, `run_ended`. It does **not** call `_request_transition()` or modify game state — signal reception only.

4. **On `run_started`**: reset — `run_active = true`, `run_outcome = NONE`, `waves_completed = 0`. GS&SF guarantees `run_started` fires before `preparation_started`, so RunManager is initialized before any downstream system reads its data.

5. **On `wave_ended`**: `waves_completed += 1`. Fires each time a regular wave clears and play returns to Preparation. At FP scope (one wave, no inter-wave return) this never fires during a run. At MVP multi-wave scope it increments once per return.

6. **On `room_cleared`**: set `run_outcome = WIN`. At MVP, `room_cleared` fires exactly once per run — when the boss is defeated. Setting outcome here ensures it is determined before `run_ended(win: true)` fires.

7. **On `run_ended(win: bool)`**: set `run_active = false`. If `win = false` **and** `run_outcome = NONE` (no `room_cleared` fired — Fayde died or player quit), set `run_outcome = LOSS`. If `win = true`, `run_outcome` is already `WIN` from Rule 6. Run data is now final. — *Note: At MVP, Fayde-died and player-quit are both treated as LOSS. Distinguishing QUIT from LOSS (listening for `death_started` vs. `PAUSED → MAIN_MENU` quit path) is a VS refinement.*

8. **Read access**: `RunManager` exposes one public method: `get_run_data() -> Dictionary`. Returns a copy of the current run record (`{ "run_active": bool, "run_outcome": RunOutcome, "waves_completed": int }`). Callers receive a copy — never a reference to the internal fields. This prevents accidental mutation by downstream screens.

9. **AutoLoad registration order**: `RunManager` must be registered after `GameStateManager` in Project Settings → AutoLoad. `RunManager._ready()` connects to `GameStateManager` signals — `GameStateManager` must exist first.

---

### States and Transitions

No formal state machine. `run_active` and `run_outcome` together represent the implicit state:

| `run_active` | `run_outcome` | Meaning |
|---|---|---|
| `false` | `NONE` | **IDLE** — no run in progress (initial state and between runs) |
| `true` | `NONE` | **ACTIVE** — run in progress, outcome not yet determined |
| `false` | `WIN` or `LOSS` | **COMPLETE** — run ended, data finalized, awaiting screen read |

No re-entrancy guard required — GS&SF guarantees `run_started` fires exactly once and `run_ended` fires exactly once per run lifecycle.

---

### Interactions with Other Systems

| System | Interface | Direction | Scope |
|---|---|---|---|
| **Game State & Scene Flow** | Receives `run_started`, `wave_ended`, `room_cleared`, `run_ended(win: bool)` | GS&SF → RunManager | MVP |
| **Run Summary Screen** (#23) | Reads finalized data via `get_run_data()` after `run_ended(win: true)` | RunManager → Summary | VS |
| **Death Screen** (GS&SF scope) | Reads data via `get_run_data()` after `run_ended(win: false)` for a potential run-end display | RunManager → Death Screen | MVP |
| **Meta-Progression** (#19) | Will read `run_outcome` to award meta-currency; interface TBD in Meta-Progression GDD | RunManager → Meta-Progression | VS |
| **Difficulty Tiers** (#20) | Will read run history to adjust difficulty; interface TBD | RunManager → Difficulty Tiers | Alpha |

*Specialist agents not consulted — lean mode. Review manually before production.*

## Formulas

Run Management at MVP scope has no runtime mathematical formulas. The system is a pure data tracker — it receives signals, updates three fields, and exposes a read-only copy. The only operations are `waves_completed += 1` (trivial integer increment) and boolean/enum assignments.

**[VS] Future formula candidates** — noted so their source is traceable to this system when those GDDs are authored:

| Future Formula | Scope | Owner GDD |
|---|---|---|
| `total_floor_nodes ≥ 1` guarantee | VS | Run Management must guarantee this for GS&SF Cipher's Trial formula (already noted in GS&SF GDD) |
| Run history query for Difficulty Tiers | Alpha | Difficulty Tiers GDD — will query run outcome history |
| Meta-currency award calculation | VS | Meta-Progression GDD — reads `run_outcome` as input |

*`systems-designer` not consulted — lean mode (no formulas at MVP scope; no balance values to propose). Review manually before production.*

## Edge Cases

- **If `run_started` fires while `run_active = true`** (a GS&SF bug — should not occur): RunManager overwrites the current run record — `run_active = true`, `run_outcome = NONE`, `waves_completed = 0`. The previous run's data is lost. Log `push_error("[RunManager] run_started received while run already active — previous run data discarded")`. This is a GS&SF invariant violation; the error log is the only recovery mechanism at MVP scope.

- **If `run_ended` fires without a preceding `run_started`** (bug — initial state is IDLE, `run_active = false`): RunManager processes the signal anyway (`run_active = false`, outcome set per `win` argument) since it has no guard. Log `push_error("[RunManager] run_ended received with no active run")`. No functional harm — data is already reset.

- **If `room_cleared` fires after `run_ended` has already set `run_active = false`** (double-signal bug): RunManager sets `run_outcome = WIN` on an inactive run record. The value is harmless — `run_active = false` tells readers the run is complete. Log a debug warning but do not treat as fatal.

- **If `wave_ended` fires with `run_active = false`** (bug — wave can't end without an active run): Increment `waves_completed` anyway to avoid special-casing, and log `push_error("[RunManager] wave_ended received with no active run")`.

- **If `get_run_data()` is called while `run_active = true`** (mid-run read): Return the current in-progress state — `run_active = true`, `run_outcome = NONE`, `waves_completed = (current count)`. This is valid behavior. Callers must not assume `get_run_data()` is only called post-run.

- **At FP scope: `wave_ended` never fires during a normal run** (one wave, no inter-wave return): `waves_completed` remains 0 at run end. This is correct — `waves_completed` counts inter-wave preparation cycles, not waves spawned. At FP scope, the single wave clears and `all_waves_cleared` → `boss_defeated` → `room_cleared` → `run_ended(win: true)` fires directly, bypassing `wave_ended` entirely.

- **If the AutoLoad registration order is wrong** (`RunManager` registered before `GameStateManager`): `RunManager._ready()` will fail to connect signals because `GameStateManager` is not yet in the scene tree. This causes a silent failure — signals are never received. Enforce order in Project Settings and add an `assert(GameStateManager != null)` guard in `RunManager._ready()`.

*`systems-designer` not consulted — lean mode. Review manually before production.*

## Dependencies

### Upstream Dependencies (Run Management depends on these)

| # | System | What Run Management uses | Dependency type |
|---|---|---|---|
| 1 | **Game State & Scene Flow** (#27) | Signals: `run_started`, `wave_ended`, `room_cleared`, `run_ended(win: bool)`. RunManager connects to these at `_ready()` and cannot function without them. | Hard |
| 2 | **Wave / Encounter System** (#12) | **Indirect dependency only** — RunManager does not connect to Wave System signals directly. Wave System emits `all_waves_cleared` and `boss_defeated` → GS&SF processes these → emits `room_cleared` and `run_ended` → RunManager receives those. The dependency on Wave System is a runtime prerequisite (wave completion drives the signals RunManager ultimately receives), not a code-level dependency. | Soft / Indirect |

### Downstream Dependents (systems that depend on Run Management)

| # | System | What it needs from Run Management | Scope |
|---|---|---|---|
| 1 | **Run Summary Screen** (#23) | Reads finalized run data via `get_run_data()` after `run_ended(win: true)` to populate the win screen | VS |
| 2 | **Death Screen** (GS&SF scope) | May read run data via `get_run_data()` after `run_ended(win: false)` for failure display | MVP |
| 3 | **Meta-Progression** (#19) | Reads `run_outcome` to determine meta-currency award; interface defined in Meta-Progression GDD | VS |
| 4 | **Difficulty Tiers** (#20) | Will query run outcome history to adjust difficulty settings; interface defined in Difficulty Tiers GDD | Alpha |
| 5 | **Game State & Scene Flow** (VS) | `total_floor_nodes ≥ 1` is a precondition RunManager must guarantee for the Cipher's Trial option-count formula; this obligation is VS scope only | VS |

### Bidirectionality Confirmation

- **GS&SF GDD** lists RunManager explicitly: "initializes run data on `run_started`; records wave result on `wave_ended`; records arena result on `room_cleared`; finalizes on `run_ended`" ✓
- **Wave System GDD** notes: "Run Management's dependency is on GS&SF signals, not Wave System signals directly — indirect dependency" ✓

## Tuning Knobs

Run Management at MVP scope has no designer-adjustable tuning knobs. The system tracks three fields and has no timers, thresholds, or configurable behaviors.

**[VS/Alpha] Future knob candidates** — for when downstream systems need them:

| Future Knob | Scope | Purpose |
|---|---|---|
| `run_history_max_count` | Alpha | Maximum number of past run outcomes to retain in memory for Difficulty Tiers to query. Not needed until Difficulty Tiers GDD is authored. |

*No tuning-knob interaction with existing GDDs. No knob cross-reference needed.*

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

*Test type key: [U] = Automated unit test | [I] = Integration test | [M] = Manual smoke-check*

**[U] AC-RM-01** — GIVEN `run_started` fires, WHEN RunManager processes it, THEN `run_active = true`, `run_outcome = NONE`, `waves_completed = 0`.

**[U] AC-RM-02** — GIVEN `run_started` fires while `run_active` is already `true`, WHEN processed, THEN fields are reset (`run_active = true`, `run_outcome = NONE`, `waves_completed = 0`) AND `push_error()` is called with a message containing `"[RunManager]"` (verified via GUT error watcher / `assert_error_logged()`).

**[U] AC-RM-03** — GIVEN a run is active, WHEN `wave_ended` fires 3 times, THEN `waves_completed = 3` AND `get_run_data()["waves_completed"] == 3`.

**[U] AC-RM-04** — GIVEN a run is active and `run_outcome = NONE`, WHEN `room_cleared` fires, THEN `run_outcome = WIN` and `run_active` remains `true`. If `room_cleared` fires a second time, `run_outcome` remains `WIN` (idempotent assignment — no error logged).

**[U] AC-RM-05** — GIVEN `run_outcome = WIN` (from `room_cleared`), WHEN `run_ended(win: true)` fires, THEN `run_active = false` and `run_outcome = WIN`.

**[U] AC-RM-06** — GIVEN `run_outcome = NONE` (no `room_cleared` fired), WHEN `run_ended(win: false)` fires, THEN `run_active = false` and `run_outcome = LOSS`.

**[U] AC-RM-07** — GIVEN `run_outcome = WIN` (from `room_cleared`), WHEN `run_ended(win: false)` fires (erroneous signal — should not occur in normal play), THEN `run_active = false` AND `run_outcome` remains `WIN` — the Rule 7 conditional guard does **not** overwrite WIN with LOSS.
*(qa-lead identified this as a blocking gap — covers the conditional branch in Core Rule 7.)*

**[U] AC-RM-08** — GIVEN `run_active = false` (no active run), WHEN `run_ended` fires, THEN `push_error()` is called with a message containing `"[RunManager]"` (GUT error watcher) and `run_active` remains `false`.

**[U] AC-RM-09** — GIVEN `run_ended` has fired, WHEN `get_run_data()` is called, THEN the returned Dictionary contains keys `"run_active"`, `"run_outcome"`, `"waves_completed"` with values matching the finalized run state.

**[U] AC-RM-10** — GIVEN `get_run_data()` is called while `run_active = true` (mid-run), WHEN the returned Dictionary is inspected, THEN `run_active = true` and `run_outcome = NONE`.

**[U] AC-RM-11** — GIVEN `get_run_data()` returns a Dictionary, WHEN the caller modifies any field in the returned Dictionary, THEN RunManager's internal `run_active`, `run_outcome`, and `waves_completed` fields are unchanged (copy semantics).

**[U] AC-RM-12** — GIVEN `wave_ended` fires while `run_active = false` (bug), WHEN processed, THEN `waves_completed` is incremented AND `push_error()` is called with a message containing `"[RunManager]"` (GUT error watcher).

**[I] AC-RM-13** — GIVEN RunManager and GameStateManager are registered as Autoloads with GameStateManager first, WHEN a full FP run completes (`run_started` → `combat_started` → all 10 enemies die → `run_ended(win: true)`), THEN `get_run_data()` returns `{ run_active: false, run_outcome: WIN, waves_completed: 0 }`.

**[M] AC-RM-14** — GIVEN RunManager is registered after GameStateManager in Project Settings → AutoLoad, WHEN the game starts, THEN RunManager is accessible globally and no signal-connection errors appear in the Godot output panel. *(Manual smoke-check — AutoLoad wiring cannot be unit-tested in GUT.)*

*qa-lead consulted (lean mode — Section H). One blocking gap fixed (AC-RM-07). Redundant single-increment AC dropped; AC-RM-03 combines wave count with get_run_data() verification.*

## Open Questions

[To be designed]
