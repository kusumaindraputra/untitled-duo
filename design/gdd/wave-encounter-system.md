# Wave / Encounter System (Simplified)

> **Status**: Designed (pending /design-review)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Pillar 1 (Every Run Tells a Different Story), Pillar 2 (Power is Earned Through Understanding), Pillar 3 (Chaos Has Consequences)

## Overview

Wave / Encounter System is the runtime layer that structures what Fayde faces in each room — which enemy archetypes appear, in what numbers, and from where. It owns the full encounter lifecycle: seeding the wave composition that Wave Peek previews during Preparation, spawning enemy instances when Combat begins, and tracking kills until the wave is cleared. This system is what makes the Preparation-phase Prana grid arrangement a *meaningful decision* rather than arbitrary layout: it defines the enemy problem the player is solving.

At **First Playable scope**, the system runs a single hardcoded encounter: one room, one wave of 8–12 enemies with a fixed multi-archetype composition (Drifter, Charger, and Cluster all present), spawning simultaneously at Combat start. This density — bullet-hell-style pressure — is intentional. It is the maximum stress test for the two-phase loop: does peeking the wave and arranging the Prana grid in advance translate into a concrete combat advantage? The run ends when the last enemy falls.

The system is the authoritative source for three event signals the Game State & Scene Flow machine depends on: `wave_cleared` (a regular wave is done, more remain — unused at FP), `all_waves_cleared` (the final regular wave is done — fires when the single FP wave clears), and `boss_defeated` (emitted immediately after `all_waves_cleared` at FP since no boss exists, completing the transition to `RUN_SUMMARY`). No other system may emit these signals.

## Player Fantasy

The fantasy of the Wave / Encounter System is **the moment of reckoning**: the Preparation phase was a bet, and the wave is where the player finds out if they read it right.

When the wave begins, 8–12 enemies fill the arena simultaneously. The chaos is immediate and readable: Drifters closing steadily from one flank, a Charger telegraphing its slow approach from another, Clusters swarming the gap between. The density creates *genuine pressure* — not noise, but the specific, legible threat of three distinct archetypes colliding in the same space. The player must move, must read the room, must cast the Prana arrangement they built without changing their mind now that the battle is live.

The peak moment is the combination landing correctly — the pre-built grid cast into the chaos, enemies thinning, surviving the frenzy, and the last enemy dissolving. That resolution is the triumph. But the tension that precedes it is what gives the triumph meaning. A player who cleared the wave easily understood the archetypes; a player who barely survived learned something. Both are correct outcomes — Pillar 3 is working when every wave result teaches the player why.

This system succeeds when a player can describe what they did and why: *"The Clusters came from the right, so I stayed left and let the Charger miss wide — the Prana cone caught the swarm first."* That sentence means the wave read as legible pressure, not random punishment.

*Pillar alignment: Pillar 2 (the wave rewards understanding of archetype behavior); Pillar 3 (chaos has consequences — the wave reveals whether the Prep-phase decision was right or wrong).*

*`creative-director` not consulted — lean mode. Review manually before production.*

## Detailed Design

### Core Rules

1. **Node architecture**: The Wave Manager is a non-visual `Node` instance — either a singleton autoload or a persistent child of the root scene. It maintains four pieces of state:
   - `_wave_composition: Array` — the (enemy_type_id, spawn_marker_index) pairs for this wave
   - `_enemies_alive: int` — current live enemy count (decremented on each `enemy_killed`)
   - `_enemies_total: int` — total enemies spawned at wave start
   - `_wave_state: WaveState` (enum: `IDLE` / `WAVE_ACTIVE` / `WAVE_COMPLETE`)

2. **FP hardcoded wave composition**: At First Playable scope, the wave composition is a constant array defined in the Wave Manager script:
   - 3 × Drifter (ID 0) — SEEKER archetype; threat value = 3
   - 2 × Charger (ID 1) — RUSHER archetype; threat value = 4
   - 5 × Cluster (ID 2) — SWARMER archetype; threat value = 5
   - **Total: 10 enemies | Threat budget: 12**

   At MVP/VS, this constant is replaced by a budget-driven composition generator. The constant form is intentional for FP — changing it is a one-line edit per iteration.

3. **Spawn markers**: The arena scene contains predefined `Node2D` spawn marker nodes (e.g., a `SpawnPoints` container with children `SP_01` through `SP_N` — minimum 10 markers for FP composition). Markers are placed at the scene level by the level designer, outside Fayde's starting position but within arena bounds. The Wave Manager reads each marker's `global_position` at spawn time; it does not own or author the marker positions. Markers are assigned to enemies in composition-array order (entry 0 → SP_01, entry 1 → SP_02, etc.). Each marker is used by at most one enemy per wave.

4. **Simultaneous spawn** (on `combat_started(is_boss: false)`): The Wave Manager instantiates all enemies from their `PackedScene` references in a single loop iteration, calls `add_child()` for each, positions each at its assigned spawn marker's `global_position`, and calls `init(enemy_type_id)` on each. All 10 enemies enter the scene tree on the same frame. `_enemies_alive = _enemies_total = 10`. `_wave_state → WAVE_ACTIVE`.

5. **Kill tracking**: The Wave Manager connects to Health & Damage's `enemy_killed(instance_id, type_id, prana_affiliation)` signal at `_ready()`. On each reception: `_enemies_alive -= 1`. When `_enemies_alive <= 0` (guard against double-emission): `_wave_state → WAVE_COMPLETE` → emit `all_waves_cleared` → emit `boss_defeated`. Both signals fire in the same handler, sequentially, in the same frame. **At FP scope**, `boss_defeated` fires immediately after `all_waves_cleared` because no boss exists; this drives `GameStateManager` from the implicit boss-combat phase to `RUN_SUMMARY` without a delay.

6. **Signal ownership and routing**: The Wave Manager is the sole emitter of `wave_cleared`, `all_waves_cleared`, and `boss_defeated`. These are defined as signals on the Wave Manager node. `GameStateManager` connects to them at `_ready()`. No other system emits these signals. Any system that reads wave progress must use the kill-count signals, not poll `_enemies_alive` directly.

7. **Phase gating**:
   - On `preparation_started(wave_index, waves_remaining)`: reset `_enemies_alive = 0`, `_enemies_total = 0`, `_wave_state = IDLE`. Used at MVP/VS to prepare the next wave between prep and combat cycles. At FP (only 1 wave), this fires once at run start.
   - On `combat_started(is_boss: false)`: begin spawn (Rule 4).
   - On `combat_started(is_boss: true)`: no-op at FP scope — guard is in place. Log a debug warning if received (indicates FP scope retired incorrectly).
   - On `game_paused` / `game_resumed`: Wave Manager has no active timers at FP scope (spawn is synchronous); no pause handling needed. Enemy `PROCESS_MODE_PAUSABLE` handles the freeze at the enemy node level.

8. **Arena dimensions constant**: The Wave Manager exposes `ARENA_WIDTH_PX` and `ARENA_HEIGHT_PX` as exported constants (default: see Tuning Knobs). Spawn marker placement and any arena-edge guards use these values. Enemy AI's `AGGRO_RADIUS = 400px` is confirmed valid for any arena ≤ 800px wide — at that threshold, all enemies aggro from spawn regardless of position, which matches FP always-chase behavior. *(Resolves Enemy AI Open Q2 — arena dimensions referenced here; `AGGRO_RADIUS` is validated as compatible with FP scope.)*

---

### States and Transitions

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| `IDLE` | No wave active; system dormant | Init / after `WAVE_COMPLETE` | → `WAVE_ACTIVE` on `combat_started(is_boss: false)` |
| `WAVE_ACTIVE` | Enemies spawned; tracking `enemy_killed` signals | All enemies instantiated in one frame | → `WAVE_COMPLETE` when `_enemies_alive <= 0` |
| `WAVE_COMPLETE` | All enemies dead; signals emitted | Last `enemy_killed` received | Terminal for FP run; GS&SF transitions to `RUN_SUMMARY` |

`WAVE_COMPLETE` is terminal per FP run — no re-entry. At MVP/VS, `WAVE_COMPLETE` on a non-final wave would return to `IDLE` via `preparation_started`.

---

### Interactions with Other Systems

| System | Interface | Direction |
|--------|-----------|-----------|
| **Game State & Scene Flow** | Listens for `preparation_started`, `combat_started`; emits `wave_cleared`, `all_waves_cleared`, `boss_defeated` | Bidirectional signals |
| **Enemy Data** | Reads `PackedScene` references and validates `status = active` before spawning; reads `enemy_type_id` to pass to `init()` | Enemy Data → Wave System |
| **Enemy AI** | Instantiates and inits each enemy node via `add_child()` + `init(enemy_type_id)`; Enemy AI activates on spawn and handles all behavior | Wave System → Enemy AI (init only) |
| **Health & Damage** | Listens for `enemy_killed(instance_id, type_id, prana_affiliation)` to decrement `_enemies_alive` | H&D → Wave System |
| **Wave Peek** (VS) | Wave Peek reads wave composition data from Wave System during `PREPARATION_PHASE` to display the preview panel | Wave System → Wave Peek *(VS scope only)* |

*Specialist agents not consulted — lean mode. Review manually before production.*

## Formulas

> *`systems-designer` not consulted — lean mode (low formula complexity at FP scope). Review manually before production.*

### Formula 1 — FP Threat Budget (Reference)

This is a design-time accounting formula, not a runtime calculation. It confirms the FP hardcoded composition is balanced relative to the threat values defined in Enemy Data.

```
threat_budget = Σ(enemy_count[i] × wave_threat_value[i])
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy count per type | `enemy_count[i]` | int | 0–N | Number of enemies of type `i` in the wave |
| Threat value per type | `wave_threat_value[i]` | int | 1–4 | From Enemy Data catalog (Drifter=1, Charger=2, Cluster=1) |
| Total threat | `threat_budget` | int | 0–unbounded | Sum of all (count × threat value) across the composition |

**FP calculation:**
`(3 × 1) + (2 × 2) + (5 × 1) = 3 + 4 + 5 = 12`

**Output Range:** 12 (FP hardcoded). At MVP+, the threat budget becomes a tuning knob cap for procedural composition.

**Example:** If one Charger is swapped for two Drifters: `(5 × 1) + (1 × 2) + (5 × 1) = 12` — budget unchanged, composition shifts toward swarm-and-pressure.

---

### Formula 2 — Wave Completion Check

```
wave_complete = (_enemies_alive <= 0)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Live enemy count | `_enemies_alive` | int | 0–`_enemies_total` | Decremented by 1 on each `enemy_killed` signal reception |
| Total spawned | `_enemies_total` | int | 10 (FP) | Set at spawn time; not modified mid-wave |
| Completion flag | `wave_complete` | bool | — | `true` when `_enemies_alive <= 0` |

**Output Range:** Boolean. Evaluated after each `enemy_killed` decrement.

**Guard:** `<= 0` (not `== 0`) protects against the unlikely case where a bug causes `_enemies_alive` to go negative — the completion check still fires, preventing a run from being softlocked in `WAVE_ACTIVE` permanently.

**Example:** 10 enemies spawn → 9 kill signals received → `_enemies_alive = 1` (not complete) → 10th kill received → `_enemies_alive = 0` → `wave_complete = true` → emit `all_waves_cleared` + `boss_defeated`.

---

### Formula 3 — MVP+ Composition Generator (Deferred — not active at FP)

At MVP/VS, wave composition is determined by a threat-budget fill algorithm:

```
while remaining_budget > 0:
    candidate = random_select(active_enemy_types, weighted_by=wave_threat_value)
    if candidate.wave_threat_value <= remaining_budget:
        add candidate to composition
        remaining_budget -= candidate.wave_threat_value
```

This formula is **not implemented at FP**. It is documented here so the Wave System's data structures (`_wave_composition` as a mutable array, `_enemies_total` as derived from it) are forward-compatible with the MVP generator without refactoring.

**Output Range (MVP+):** Total threat = `WAVE_THREAT_BUDGET` tuning knob. Enemy count varies by composition.

## Edge Cases

> *`systems-designer` not consulted — lean mode. Review manually before production.*

- **If `enemy_killed` fires with an `instance_id` that Wave Manager never spawned**: Decrement `_enemies_alive` anyway — Wave Manager does not validate `instance_id` against its spawn list. The signal is authoritative (H&D is the emitter); Wave Manager trusts it. If a non-wave enemy (e.g., a test instance) is killed and H&D emits `enemy_killed`, `_enemies_alive` may go negative — the `<= 0` guard in Formula 2 still triggers wave completion. At FP scope (no non-wave enemies) this is harmless; at MVP+ with non-wave enemies (patrol, shop guard), Wave Manager must filter by its own spawn registry.

- **If `enemy_killed` fires twice for the same `instance_id`** (H&D bug — dead-target guard should prevent this): `_enemies_alive` decrements twice. If this causes premature wave completion, it is an H&D bug to fix; Wave Manager does not deduplicate `instance_id`. No cross-system guard is added here — H&D's dead-target guard (Rule 2, step 2) is the existing protection.

- **If fewer spawn markers exist than the wave composition requires** (scene authoring error): Wave Manager detects the mismatch when iterating the composition array — the marker index is out of bounds. Guard: if the marker does not exist, log a `push_error()` and skip that enemy (continue spawning remaining enemies). Wave completion count is adjusted to the actual spawn count. This prevents a run from being softlocked if an enemy fails to spawn.

- **If all spawn markers are stacked at the same position**: All enemies spawn on top of each other. Enemy AI's degenerate-direction guard (Formula 1, Enemy AI GDD) handles the `dir.length() < 0.01` case correctly — enemies slide apart naturally within the first physics frame. No Wave Manager intervention needed.

- **If `combat_started(is_boss: true)` fires while `_wave_state == WAVE_ACTIVE`** (should not occur at FP — indicates GS&SF sent boss start before wave was cleared): Wave Manager logs a debug warning and ignores the signal. `_wave_state` remains `WAVE_ACTIVE`. The existing wave must clear before any state change.

- **If the run ends (Fayde dies) while `_wave_state == WAVE_ACTIVE`**: `player_died` is emitted by H&D; GS&SF transitions to `DEATH_SCREEN`. Wave Manager does not emit `all_waves_cleared` or `boss_defeated` — the run is over. Remaining enemy nodes are freed when the arena scene is unloaded by `SceneManager`. Wave Manager's `_enemies_alive` is left non-zero, but the node transitions to a new run on the next `run_started` (which triggers `preparation_started` → reset).

- **If `_enemies_alive` somehow reaches `<= 0` before all enemies are killed** (e.g., no enemies were spawned or all spawns failed): After the spawn loop, if `_enemies_total == 0`, log `push_error()` and immediately emit `all_waves_cleared` + `boss_defeated` to prevent the run from softlocking in `WAVE_ACTIVE` indefinitely. No enemies → wave is vacuously complete.

## Dependencies

### Upstream Dependencies (Wave System depends on these)

| # | System | What Wave System reads/uses | Contract |
|---|--------|--------------------------|---------|
| 1 | **Enemy Data** | Enemy type definitions (`id`, `status`, `wave_threat_value`) for composition validation; `PackedScene` references per type for instantiation | Only `status = active` entries are spawnable. `wave_threat_value = null` entries (boss) must be filtered out. Enemy Data is the authoritative source — Wave System never defines its own enemy types. |
| 2 | **Enemy AI** | Each spawned enemy node receives `init(enemy_type_id)` after `add_child()`; Enemy AI handles all runtime behavior from there | Enemy AI owns the instance lifecycle post-spawn. Wave System owns the spawn event only. |
| 3 | **Health & Damage** | Listens for `enemy_killed(instance_id, type_id, prana_affiliation)` signal to decrement `_enemies_alive` and evaluate wave completion | H&D is the authority on enemy death events — Wave System never tracks HP directly. H&D's dead-target guard prevents duplicate `enemy_killed` emissions. |
| 4 | **Game State & Scene Flow** | Listens for `preparation_started(wave_index, waves_remaining)` to reset state; listens for `combat_started(is_boss: false)` to begin spawning | GS&SF drives the state machine; Wave System reacts to its signals. Wave System connects to `GameStateManager` autoload at `_ready()`. |

### Downstream Dependents (systems that depend on Wave System)

| # | System | What it needs from Wave System | Bidirectional contract |
|---|--------|-------------------------------|----------------------|
| 5 | **Game State & Scene Flow** | `wave_cleared` (more waves remain → PREP), `all_waves_cleared` (final wave done → boss phase), `boss_defeated` (boss done → RUN_SUMMARY) | Wave System is the sole emitter; GS&SF must declare Wave System as a dependency. Signal timing is synchronous — no deferred or async emit. |
| 6 | **Wave Peek** (#13, VS) | Wave composition data during PREPARATION_PHASE — which enemy types and counts to display in the preview panel | Wave Peek GDD must declare Wave System as a dependency. Interface TBD in Wave Peek GDD. |
| 7 | **Boss Encounter** (#11, VS) | Wave System provides the boss wave trigger (`combat_started(is_boss: true)`) path and boss win/loss signals | Boss Encounter GDD must declare Wave System and GS&SF as dependencies. |
| 8 | **Run Management** (#17, MVP) | Listens for `wave_ended` (if multi-wave at MVP) and `room_cleared` from GS&SF (downstream of `boss_defeated`) to record run progress | Run Management's dependency is on GS&SF signals, not Wave System signals directly — indirect dependency. |
| 9 | **Difficulty Tiers** (#20, Alpha) | At Alpha, difficulty modifiers will adjust `WAVE_THREAT_BUDGET` and composition weights — accessed via tuning knob interface | Difficulty Tiers GDD must declare Wave System as a dependency when authored. |

### Bidirectionality Note

Enemy AI GDD (Downstream Dependents table, item 5) states: *"Wave / Encounter System spawns enemy instances; provides `enemy_type_id` at spawn; tracks wave progress via H&D's `enemy_killed` (not via Enemy AI directly). Wave System owns spawn/despawn lifecycle; Enemy AI handles behavior. Wave System GDD must declare Enemy AI as a dependency."* — confirmed here.

Health & Damage GDD (Interactions table) states Wave System listens for `enemy_killed` — confirmed and listed above.

Game State & Scene Flow GDD (Downstream Dependents table) explicitly lists Wave System and its signal contract — confirmed.

## Tuning Knobs

| Knob | Constant Name | Default Value | Safe Range | What It Affects | What Breaks If Wrong |
|------|---------------|---------------|------------|-----------------|----------------------|
| FP Drifter count | `FP_DRIFTER_COUNT` | 3 | 1–6 | Steady pressure volume; Drifters are the constant threat | Below 1: archetype missing from FP test; above 6 with Clusters: arena becomes unnavigable |
| FP Charger count | `FP_CHARGER_COUNT` | 2 | 1–4 | High-burst threat frequency | Above 3: Charger density removes dodging room; below 1: archetype missing |
| FP Cluster count | `FP_CLUSTER_COUNT` | 5 | 3–8 | Swarm density; the bullet-hell "fill" | Below 3: swarm archetype loses its pressure character (Enemy Data Edge Case 5); above 8: arena may become impassable from enemy collision |
| Arena width (placeholder) | `ARENA_WIDTH_PX` | 0 (unset — must be set at scene level) | 640–1920 | Affects spawn marker placement and AGGRO_RADIUS validation | Not set: Wave Manager cannot validate spawn markers; zero-arena causes all enemies to stack at origin |
| Arena height (placeholder) | `ARENA_HEIGHT_PX` | 0 (unset — must be set at scene level) | 480–1080 | Same as above for vertical axis | Same as above |
| Wave threat budget (MVP+) | `WAVE_THREAT_BUDGET` | 12 (matches FP hardcoded) | 8–30 | At MVP+, total threat value cap for procedural composition generator | Below 8: wave too sparse to feel threatening; above 20: composition so dense the frame budget may be stressed (profile before setting above 20) |

**Cross-system tuning notes:**
- `FP_CLUSTER_COUNT` lower bound (3) is enforced by Enemy Data Edge Case 5 — spawning fewer than 3 Clusters defeats the archetype's swarm design intent.
- `ARENA_WIDTH_PX` must be set before implementing spawn markers. Enemy AI's `AGGRO_RADIUS = 400px` is validated against arenas ≤ 800px wide — raising arena above 800px means enemies will not aggro from the far edge of the arena at spawn. This is acceptable if spawn markers are placed within 400px of Fayde's start position.
- Cluster count above 8 should be profiled: 8+ simultaneously `PROCESS_MODE_PAUSABLE` physics objects each running `move_and_slide()` may approach frame budget limits on target hardware. Profile at ≥ 8 Clusters before shipping.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

> *`qa-lead` not consulted — lean mode. Review manually before production.*

### Wave Composition

- **AC-WES-01** — GIVEN the Wave Manager script is loaded, WHEN `FP_DRIFTER_COUNT`, `FP_CHARGER_COUNT`, `FP_CLUSTER_COUNT` are read, THEN their values equal 3, 2, 5 respectively and sum to 10.
- **AC-WES-02** — GIVEN the FP composition array, WHEN each entry is validated against Enemy Data, THEN all `enemy_type_id` values exist in the Enemy Data catalog with `status = active` AND `wave_threat_value` is not null.
- **AC-WES-03** — GIVEN the FP composition (3 Drifter + 2 Charger + 5 Cluster), WHEN the threat budget is calculated, THEN total = `(3×1) + (2×2) + (5×1) = 12`.

### Spawn Sequence

- **AC-WES-04** — GIVEN `combat_started(is_boss: false)` fires and the arena scene contains at least 10 spawn markers, WHEN the spawn loop completes, THEN exactly 10 enemy nodes are in the scene tree, `_enemies_alive = 10`, `_enemies_total = 10`, `_wave_state = WAVE_ACTIVE`. All 10 nodes are added in the same frame (no deferred add).
- **AC-WES-05** — GIVEN an enemy node is added by the Wave Manager, WHEN `init(enemy_type_id)` is called on it, THEN the enemy's `_archetype`, `_base_damage`, `_move_speed` fields match the Enemy Data definition for that `enemy_type_id` (verified by Enemy AI AC-EAI-03a/b/c).
- **AC-WES-06** — GIVEN the arena scene has fewer spawn markers than the composition count, WHEN the spawn loop runs, THEN a `push_error()` is logged; the remaining enemies (up to the marker count) are spawned; `_enemies_total` equals the number actually spawned (not the composition count).

### Kill Tracking

- **AC-WES-07** — GIVEN `_wave_state = WAVE_ACTIVE` and `_enemies_alive = 5`, WHEN `enemy_killed` fires once, THEN `_enemies_alive = 4` and `_wave_state` remains `WAVE_ACTIVE`.
- **AC-WES-08** — GIVEN `_enemies_alive = 1` and `_wave_state = WAVE_ACTIVE`, WHEN the final `enemy_killed` fires, THEN `_enemies_alive = 0` and `_wave_state = WAVE_COMPLETE` after the handler returns.

### Wave Completion Signals

- **AC-WES-09** — GIVEN `_enemies_alive` reaches 0 (wave complete), WHEN the completion handler runs, THEN `all_waves_cleared` is emitted exactly once AND `boss_defeated` is emitted exactly once, in that order, in the same handler call (synchronous, same frame).
- **AC-WES-10** — GIVEN the Wave Manager has already entered `WAVE_COMPLETE` (signals emitted), WHEN another `enemy_killed` fires (late signal — duplicate or bug), THEN `_wave_state` remains `WAVE_COMPLETE` and neither `all_waves_cleared` nor `boss_defeated` is re-emitted.
- **AC-WES-11** — GIVEN `_enemies_total = 0` after the spawn loop (all spawns failed), WHEN the guard check runs after spawn, THEN `push_error()` is logged, `all_waves_cleared` is emitted, `boss_defeated` is emitted, and `_wave_state = WAVE_COMPLETE`. Run does not softlock.

### Phase Gating

- **AC-WES-12** — GIVEN `_wave_state = WAVE_ACTIVE`, WHEN `combat_started(is_boss: true)` fires, THEN `_wave_state` remains `WAVE_ACTIVE`, no enemies are spawned, and a debug warning is logged.
- **AC-WES-13** — GIVEN `_wave_state = WAVE_COMPLETE` from a finished run, WHEN `preparation_started` fires (next run start), THEN `_enemies_alive = 0`, `_enemies_total = 0`, `_wave_state = IDLE`. System is ready for the next spawn.

### Integration

- **AC-WES-14** — Full FP run flow: (1) `preparation_started` fires → state = IDLE; (2) `combat_started(is_boss: false)` fires → 10 enemies spawned, `_wave_state = WAVE_ACTIVE`; (3) 10 × `enemy_killed` signals received → `_enemies_alive` reaches 0 → `all_waves_cleared` emitted → `boss_defeated` emitted → `_wave_state = WAVE_COMPLETE`. Verify signal emission counts: `all_waves_cleared` exactly 1, `boss_defeated` exactly 1.
- **AC-WES-15** — GIVEN Fayde dies (H&D emits `player_died`) while `_wave_state = WAVE_ACTIVE`, WHEN the run ends and GS&SF transitions to `DEATH_SCREEN`, THEN Wave Manager does not emit `all_waves_cleared` or `boss_defeated`. Enemy nodes are freed by scene unload; Wave Manager state is reset on next `preparation_started`.

## Open Questions

[To be designed]
