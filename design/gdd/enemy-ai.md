# Enemy AI (Simplified)

> **Status**: Designed (pending /design-review)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-28
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding), Pillar 3 (Chaos Has Consequences)

## Overview

Enemy AI owns the runtime behavior of every enemy instance in The Last Cipher. It is responsible for three behaviors: **movement** (approaching Fayde during Combat phase), **attack** (dealing contact damage on overlap), and **death sequencing** (crumple → bloom → dissolve animation and one-frame node-lifetime guarantee after `enemy_killed` fires). Behavior is archetype-routed: three archetypes from Enemy Data map to three distinct behavioral patterns — SEEKER (Drifter) pursues Fayde at constant speed; RUSHER (Charger) telegraphs a directional charge burst; SWARMER (Cluster) moves in loose formation with other Swarmer units, threatening only in groups.

At **First Playable scope**, all three archetypes implement a simplified form: direct screen-space vector movement toward Fayde's position each physics frame, and a single contact-damage call per `ENEMY_MIN_CONTACT_INTERVAL` when overlapping Fayde's collision area. No navmesh, no formation logic, no Charger wind-up telegraph at FP. The archetype routing scaffolding is in place so fuller patterns arrive at MVP/VS without structural refactor.

Enemy AI operates exclusively in `COMBAT_PHASE` — all enemy processing suspends during `PREPARATION_PHASE` and `PAUSED`. Enemy instances are spawned and despawned by Wave / Encounter System; Enemy AI activates on spawn and deactivates when `enemy_killed` fires. All HP tracking and damage application are delegated to Health & Damage: `apply_damage(fayde, enemy.base_damage, null, DamageSource.CONTACT)` exactly once per contact event.

## Player Fantasy

The fantasy of Enemy AI is **legible threat**. Fayde's combat is two-phase by design: in Preparation you arrange the grid knowing what's coming; in Combat you find out if you read it right. Enemy AI is what makes "what's coming" feel real.

Each archetype delivers a distinct emotional pressure. The **Drifter** is steady menace — it does not rush, it just closes the distance at a pace that always feels like it will reach you exactly when you don't want it to. It teaches patience and spacing. The **Charger** is the moment of commitment: a slow approach, then the burst — a test of whether the player read the wind-up and repositioned, or didn't. The satisfaction of a clean dodge is earned by the dread that preceded it. The **Cluster** is arithmetic becoming terror: individually each unit is negligible; three at once means Fayde's position has to be deliberate or the contact interval stack becomes a problem.

The combined fantasy is **the feeling of a wave that was understood**: Drifters peeled off the right flank, Charger dodged with a well-timed dash, Cluster caught in the Prana cone and thinned fast. When the player can describe what they did and *why* it worked — "I stayed center so the Charger charge went wide; the Clusters couldn't swarm from there" — Enemy AI is delivering Pillar 2 fully.

At FP scope, the simplified behavior (direct movement + contact damage) is intentionally legible: no hidden logic, no surprising patterns. The archetypes distinguish themselves through their stat profiles (Drifter fast and light; Charger slow and heavy; Cluster fragile and numerous) before more complex behavior is layered in at MVP/VS.

*`creative-director` not consulted — lean mode. Review manually before production.*

## Detailed Design

### Core Rules

1. **Node architecture**: Each enemy instance is a `CharacterBody2D` scene with `process_mode = PROCESS_MODE_PAUSABLE`. Standard child nodes:
   - `Sprite2D` — enemy sprite (dimensions from Enemy Data `sprite_size`)
   - `CollisionShape2D` — movement collision (arena walls)
   - `AnimationPlayer` — idle, hit flash, death animations
   - `Area2D` + `CollisionShape2D` (child) — dedicated contact hitbox; separate from movement collision to allow decoupled tuning

2. **Archetype routing**: At `_ready()` (or via an `init(enemy_type_id)` call from the spawner), the node looks up the type definition from Enemy Data by `enemy_type_id` and caches `_archetype`, `_base_damage`, and `_move_speed`. At FP scope all three archetypes use identical behavior. The `_archetype` field is stored now so that MVP/VS can route to distinct `_tick_seeker()` / `_tick_rusher()` / `_tick_swarmer()` functions without structural changes.

3. **Phase gating**: Connects to `GameStateManager` at `_ready()`:
   - `combat_started` → `_combat_active = true`
   - `preparation_started` → `_combat_active = false`, `velocity = Vector2.ZERO`, stop `_contact_timer`
   - `_physics_process` first statement: `if not _combat_active or _state == EnemyState.DEAD: velocity = Vector2.ZERO; return`
   - `PROCESS_MODE_PAUSABLE` handles `game_paused` automatically.

4. **FP movement (all archetypes)**: Each `_physics_process(delta)`:
   - Get Fayde reference: `_fayde_ref = get_tree().get_first_node_in_group(&"player")` — cached at `_ready()`; re-resolved if null
   - `dir = (fayde_ref.global_position - global_position).normalized()`
   - `velocity = dir * _move_speed`
   - `move_and_slide()`
   - Degenerate case (`dir.length() < 0.01`): hold last valid direction; do not zero — prevents jitter when enemy is already at Fayde's position

5. **Contact attack**: Child `Area2D` fires signals when Fayde's `CharacterBody2D` enters/exits:
   - `body_entered(body)`: if `body.is_in_group("player")` → `_fayde_in_contact = true` → call `apply_damage(fayde, _base_damage, null, DamageSource.CONTACT)` immediately → start `_contact_timer` (period = `ENEMY_MIN_CONTACT_INTERVAL`)
   - `_contact_timer.timeout`: if `_fayde_in_contact` → call `apply_damage()` again
   - `body_exited(body)`: if `body.is_in_group("player")` → `_fayde_in_contact = false` → stop `_contact_timer`
   - **Hard constraint** (H&D Dependency #5): `ENEMY_MIN_CONTACT_INTERVAL` must be ≥ 0.3s. H&D's i-frame protection against Cluster swarms depends on this. Violation renders i-frames near-zero in dense swarms.

6. **Death sequencing**: Connects to H&D's global `enemy_killed` signal at `_ready()`. On `enemy_killed(instance_id, type_id, prana_affiliation)`:
   - If `instance_id != get_instance_id()`: return (not this enemy)
   - State → `DEAD`; `velocity = Vector2.ZERO`; stop `_contact_timer`; `$HitArea.monitoring = false` (disables Area2D — no further contact events)
   - `$AnimationPlayer.play("death")` — crumple → bloom → dissolve (spec in Visual/Audio section)
   - On `AnimationPlayer.animation_finished("death")`: `queue_free()` — **must use `queue_free()` only, never `free()`** — this preserves the one-frame node-lifetime guarantee required by H&D Rule 5 so Prana Drop / Loot can resolve position via `instance_from_id()`.

7. **Group membership** (hard constraint from H&D target discrimination contract):
   - Enemy instances **must** be added to the `"enemy"` group at `_ready()`: `add_to_group(&"enemy")`
   - Enemy instances must **NOT** be in the `"player"` group — listeners on `damage_taken` and `heavy_hit` use `target.is_in_group("player")` to distinguish Fayde from enemies

---

### States and Transitions

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| `CHASING` | Moving toward Fayde; contact attack armed | Default on spawn (enemies spawned during COMBAT_PHASE only) | → `DEAD` on self `enemy_killed` |
| `DEAD` | Death animation playing; no movement, no attack | `_on_self_killed()` | Terminal — node `queue_free()` after animation |

**Phase overlay** (orthogonal to state machine):

| `_combat_active` | Meaning | Effect |
|-----------------|---------|--------|
| `true` | COMBAT_PHASE active | `_physics_process` runs; contact attack armed |
| `false` | PREPARATION_PHASE or not yet started | Velocity zeroed; contact timer stopped; state machine frozen |

`DEAD` takes precedence over `_combat_active`: a dead enemy never resumes movement if `combat_started` fires mid-death-animation.

---

### Interactions with Other Systems

| System | Interface | Direction |
|--------|-----------|-----------|
| **Enemy Data** | Lookup by `enemy_type_id` at spawn: reads `archetype`, `base_damage`, `base_move_speed` | Enemy Data → Enemy AI |
| **Game State & Scene Flow** | `combat_started` / `preparation_started` toggle `_combat_active` | Game State → Enemy AI |
| **Health & Damage** | Calls `apply_damage(fayde, _base_damage, null, DamageSource.CONTACT)` per contact event; listens for `enemy_killed(instance_id, ...)` to detect own death | Enemy AI ↔ H&D |
| **Wave / Encounter System** | Spawns enemy instances, provides `enemy_type_id`; Enemy AI does not call back — wave progress flows via H&D's `enemy_killed` | Wave System → Enemy AI (spawn init) |
| **Spell Casting & Effects** | SC&E calls `apply_damage(enemy_node, spell_damage, element, DamageSource.DIRECT)` directly to H&D; Enemy AI is not in this path | SC&E → H&D (Enemy AI provides the enemy target node) |
| **Status Effects (MVP)** | At FP scope: not applicable. At MVP: Enemy AI will need to expose `apply_speed_modifier(multiplier: float)` for Freeze/Slow | Status Effects → Enemy AI *(deferred)* |
| **Prana Drop / Loot (VS)** | Enemy AI guarantees node-lifetime by using `queue_free()` only in death sequence; Prana Drop resolves position via `instance_from_id()` within the same frame as `enemy_killed` | Implicit (no direct call) |

*Specialist agents not consulted — lean mode. Review manually before production.*

## Formulas

### Formula 1 — Degenerate Direction Guard

The direction vector `(fayde_pos - enemy_pos)` collapses to zero when an enemy occupies the same position as Fayde. `Vector2.ZERO.normalized()` produces `NaN` in GDScript, which propagates through `move_and_slide()` and crashes. The guard prevents this:

```
dir_this_frame = (dir.length() >= 0.01) ? dir.normalized() : _dir_last_valid
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Raw direction | `dir` | Vector2 | any | `fayde_pos - global_position` this frame |
| Direction length | `dir.length()` | float | 0 – unbounded | Euclidean distance to Fayde in px |
| Cached direction | `_dir_last_valid` | Vector2 (normalized) | unit vectors | Last frame's valid normalized direction; initialized to `Vector2.RIGHT` at spawn |
| Output direction | `dir_this_frame` | Vector2 (normalized) | unit vectors | Direction used for velocity this frame |

**Output Range:** Always a unit vector. When degenerate, uses last cached direction to prevent any change in momentum.

**Example — enemy directly on top of Fayde:**
`dir = (0, 0)`, `dir.length() = 0 < 0.01` → use `_dir_last_valid = (1, 0)` → `velocity = (1, 0) × 80 = (80, 0) px/s`. Enemy slides out of the degenerate position on the next frame.

---

### Formula 2 — Effective Move Speed Under Status Effects (MVP — not active at FP)

Already defined in registry (`source: design/gdd/enemy-data.md`). Included here for Enemy AI's implementation contract:

```
effective_move_speed = base_move_speed × max(0, 1 - slow_pct)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base speed | `base_move_speed` | float (px/s) | 50–80 | Cached from Enemy Data at spawn |
| Slow fraction | `slow_pct` | float | 0.0–1.0 | Applied by Status Effects (Freeze = 0.50); always 0.0 at FP scope |
| Output | `effective_move_speed` | float (px/s) | 0 – `base_move_speed` | Speed used in velocity expression each frame |

**Application:** Replaces `_move_speed` in the velocity expression each physics frame — re-evaluated from current `slow_pct` rather than multiplied onto a post-normalized vector. The `max(0, ...)` guard future-proofs against a root effect (`slow_pct > 1.0`) that would reverse direction.

**Example — Drifter under Freeze:** `80 × max(0, 1 - 0.50) = 40 px/s`

**Cross-system note:** `slow_pct = 1.0` produces `v_eff = 0` (correct speed for Stun). However, Stun also requires pausing the `_dir_last_valid` cache so the direction does not continue tracking Fayde while velocity is zeroed. This distinction means Stun must be implemented via a separate `apply_stun(duration)` interface at MVP, not via `slow_pct`. See Open Questions.

---

### Formula 3 — Death Animation Duration

```
death_anim_duration = BASE_DEATH_DURATION × tier_scale
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base duration | `BASE_DEATH_DURATION` | float (s) | 0.5 – 1.0 | Tuning anchor for all death animations |
| Tier scale | `tier_scale` | float | 0.75 – 1.50 | Per-archetype multiplier (see table) |
| Output | `death_anim_duration` | float (s) | 0.40 – 1.05 | Total crumple → bloom → dissolve duration |

**Tier scale table (at `BASE_DEATH_DURATION = 0.7s`):**

| Enemy | Archetype | `tier_scale` | Duration | Frames at 60fps |
|-------|-----------|-------------|----------|-----------------|
| Cluster | SWARMER | 0.75 | **0.53s** | 32f |
| Drifter | SEEKER | 1.00 | **0.70s** | 42f |
| Charger | RUSHER | 1.50 | **1.05s** | 63f |

**Output range:** Minimum 0.40s (3 phases × 8f hard floor for visual legibility at 60fps). Subject to art team iteration.

**Node-lifetime constraint**: The `queue_free()` call fires on `AnimationPlayer.animation_finished` — not on a timer. Any duration satisfies H&D's one-frame node-lifetime guarantee, since even the shortest death animation (0.53s Cluster) far exceeds one frame (16.7ms at 60fps).

---

### Contact Interval Analysis (not a formula — confirms a constant)

`ENEMY_MIN_CONTACT_INTERVAL = 0.3s` is confirmed correct by safety ratio analysis:

```
safety_ratio = FAYDE_IFRAME_DURATION / ENEMY_MIN_CONTACT_INTERVAL = 0.5 / 0.3 = 1.67
```

The i-frame window (0.5s) always outlasts one contact retry (0.3s), guaranteeing every overlapping enemy's first retry is blocked regardless of swarm size. **Co-tuning constraint:** If `FAYDE_IFRAME_DURATION` is ever reduced below 0.3s, `ENEMY_MIN_CONTACT_INTERVAL` must be raised above the new i-frame value. These two constants must be tuned together.

---

### MVP Formula Note — Aggro Radius

At FP scope: no aggro check — all enemies chase Fayde from spawn. At MVP when non-wave-spawned patrol enemies are introduced, the check will be:

```
is_aggro = (enemy_pos - fayde_pos).length() ≤ AGGRO_RADIUS
```

Proposed default: `AGGRO_RADIUS = 400px`. Pending confirmation of final arena pixel dimensions from Level GDD or Wave/Encounter GDD.

## Edge Cases

**1. Fayde node reference null at spawn**
- **If** `get_tree().get_first_node_in_group("player")` returns `null` at `_ready()` (Fayde not yet in the scene tree): cache `_fayde_ref = null`. In `_physics_process`, if `_fayde_ref == null`, re-attempt lookup each frame. If still null, hold position (velocity = Vector2.ZERO). Enemy idles until Fayde is found. This prevents a null-access crash on the first physics tick.

**2. Enemy spawned before `combat_started` fires**
- **If** Wave / Encounter System spawns an enemy instance during PREPARATION_PHASE (should not occur at FP, but guard is present): `_combat_active` defaults to `false` at init. Enemy holds position and does not attack until `combat_started` fires. No damage occurs. State machine enters `CHASING` but `_physics_process` early-returns on `not _combat_active`.

**3. `enemy_killed` fires for a different instance**
- **If** another enemy's `enemy_killed` signal is received: the `if instance_id != get_instance_id(): return` guard in `_on_self_killed()` silently discards it. No state change, no animation trigger. Each enemy evaluates its own instance_id independently.

**4. `combat_started` fires while in `DEAD` state**
- **If** Wave / Encounter System starts a new wave (fires `combat_started`) while this enemy's death animation is still playing (transitioning from the previous wave): `_combat_active` is set to `true`, but the `DEAD` state guard in `_physics_process` (`if _state == EnemyState.DEAD: return`) prevents any movement or attack. The death animation completes and `queue_free()` fires normally. This is expected behavior during the rare edge case where wave transition overlaps with lingering death sequences.

**5. Contact damage call during death animation**
- **If** Fayde is still overlapping when `_on_self_killed()` fires (enemy died mid-overlap): `_contact_timer` is stopped and `$HitArea.monitoring = false` in the death handler. No further `body_entered` or `_contact_timer.timeout` events fire. The in-progress contact does not re-trigger after `DEAD`.

**6. `apply_damage` rejected by H&D dead-target guard on an enemy already at 0 HP**
- **If** Spell Casting & Effects or Status Effects (MVP) calls `apply_damage` on an enemy that has already reached 0 HP and entered `DEAD` state: H&D's dead-target guard (Rule 2, step 2) returns immediately — no second `enemy_killed` emission, no double-death. Enemy AI's `DEAD` state guard independently ensures no further movement or attack regardless. Both systems have independent guards; neither depends on the other for safety.

**7. Death animation `"death"` not found in `AnimationPlayer`**
- **If** the AnimationPlayer does not have a `"death"` animation (art asset missing at development time): GDScript's `AnimationPlayer.play("death")` on a missing animation name does nothing and emits a warning — it does not crash. The death sequence stalls: `queue_free()` never fires, the node persists, and the enemy appears frozen at 0 HP. Mitigation: add a fallback in `_on_self_killed()` — after calling `play("death")`, start a one-shot timer (duration = `BASE_DEATH_DURATION`) connected to `queue_free()` as a safety net if no animation completes.

**8. `queue_free()` vs. `free()` violation (implementation guard)**
- **If** a programmer calls `free()` instead of `queue_free()` on an enemy node immediately after `enemy_killed` fires: Prana Drop / Loot's `instance_from_id()` call may return an invalid node in the same frame, violating H&D Rule 5's one-frame guarantee. GDScript cannot enforce this at compile time. Mitigation: document this constraint here and in Acceptance Criteria. Prana Drop / Loot must always guard with `is_instance_valid()` regardless.

**9. Cluster minimum spawn count (cross-system)**
- **If** Wave / Encounter System spawns a single Cluster unit instead of the recommended 3–5: the unit behaves identically to a Drifter (same code path, different stats). The swarm feel is absent. This is Wave / Encounter System's responsibility to enforce (Enemy Data Edge Case 5). Enemy AI does not enforce group size — it has no awareness of sibling instances at FP scope.

## Dependencies

### Upstream Dependencies (Enemy AI depends on these)

| # | System | What Enemy AI reads/uses | Contract |
|---|--------|--------------------------|---------|
| 1 | **Enemy Data** | `archetype`, `base_damage`, `base_move_speed` — looked up by `enemy_type_id` at spawn | Enemy Data is the authoritative source; Enemy AI caches values at init and does not re-query mid-wave |
| 2 | **Player Controller** | Fayde's `global_position` each physics frame; Fayde node must be in the `"player"` group | Player Controller must maintain `"player"` group membership on the Fayde node; Enemy AI accesses position via the cached node reference |
| 3 | **Health & Damage** | Calls `apply_damage(fayde, base_damage, null, DamageSource.CONTACT)` per contact event; listens for `enemy_killed(instance_id, ...)` signal to detect own death | H&D owns HP state and death signal emission; Enemy AI never tracks HP directly. Enemy AI must enforce `ENEMY_MIN_CONTACT_INTERVAL ≥ 0.3s` — H&D's i-frame guarantee depends on it (H&D Dependency #5) |
| 4 | **Game State & Scene Flow** | `combat_started` / `preparation_started` signals to toggle `_combat_active` | Accessed via `GameStateManager` autoload; Enemy AI connects in `_ready()` |

### Downstream Dependents (systems that depend on Enemy AI)

| # | System | What it needs from Enemy AI | Bidirectional contract |
|---|--------|----------------------------|----------------------|
| 5 | **Wave / Encounter System** | Spawns enemy instances; provides `enemy_type_id` at spawn; tracks wave progress via H&D's `enemy_killed` (not via Enemy AI directly) | Wave System owns spawn/despawn lifecycle; Enemy AI handles behavior. Wave System GDD must declare Enemy AI as a dependency |
| 6 | **Spell Casting & Effects** | Enemy nodes are targets for spell projectile/AoE collision; SC&E calls `apply_damage(enemy_node, ...)` with the enemy node as the target | Enemy nodes must be in the `"enemy"` group so SC&E can distinguish them from the player node. SC&E GDD must declare Enemy AI as a dependency |
| 7 | **Status Effects (MVP)** | Will call `apply_speed_modifier(multiplier: float)` for Freeze/Slow and `apply_stun(duration: float)` for Stun | At FP scope: not applicable. Enemy AI must expose these methods at MVP without breaking FP behavior. Status Effects GDD must declare Enemy AI as a dependency when authored |
| 8 | **Prana Drop / Loot (VS)** | Relies on enemy node remaining valid for at least one frame after `enemy_killed` fires (node-lifetime guarantee) | Enemy AI enforces this guarantee by using `queue_free()` only (never `free()`) in `_on_self_killed()`. Prana Drop must guard with `is_instance_valid()` regardless (H&D Rule 5) |
| 9 | **Combat HUD** | Indirectly — H&D signals `damage_taken`, `enemy_killed` carry enemy info that Combat HUD may display | No direct call to Enemy AI; HUD listens to H&D signals |

### Bidirectionality Note

All systems that Enemy AI calls (H&D, Enemy Data, Game State) must list Enemy AI in their own Dependencies sections. Enemy Data GDD explicitly states: *"Enemy AI must declare Enemy Data as a dependency in its GDD"* — confirmed here.

The `"player"` / `"enemy"` group convention (target discrimination) is a shared contract between Player Controller, Enemy AI, Health & Damage, Spell Casting & Effects, and Combat HUD. It is documented in H&D's Dependencies section and must not be changed unilaterally.

## Tuning Knobs

| Knob | Constant Name | Default Value | Safe Range | What It Affects | What Breaks If Wrong |
|------|---------------|---------------|------------|-----------------|----------------------|
| Contact interval | `ENEMY_MIN_CONTACT_INTERVAL` | 0.3s | 0.3s – 0.49s | How fast contact-damage enemies stack pressure on Fayde; minimum swarm pacing | **Upper bound constraint: must stay below `FAYDE_IFRAME_DURATION` (0.5s)** — if interval ≥ 0.5s, retries land outside the i-frame window and Cluster swarms provide no protection (Formula 3 co-tuning). Lower bound 0.3s is a gameplay floor — below this, contact spam feels unfair regardless of i-frames |
| Base death duration | `BASE_DEATH_DURATION` | 0.7s | 0.5s – 1.0s | Overall pacing of enemy deaths; how long the arena stays "cluttered" with dying enemies | Below 0.5s: crumple → bloom → dissolve reads as one undifferentiated flash (each phase needs ≥ 8f). Above 1.0s: dense Cluster waves create a wall of dissolving corpses that obscures live enemies |
| Cluster tier scale | `DEATH_TIER_SCALE_SWARMER` | 0.75 | 0.60 – 0.90 | Cluster death animation length relative to base | Below 0.60: animation too fast to read as distinct from an instant kill. Above 0.90: Cluster deaths start feeling weighty — reduces contrast with Charger's death |
| Drifter tier scale | `DEATH_TIER_SCALE_SEEKER` | 1.00 | 0.85 – 1.15 | Drifter death animation length; the "baseline" feel | Keeping near 1.0 maintains it as the reference point. Large deviations distort the relative weight of Cluster vs. Charger deaths |
| Charger tier scale | `DEATH_TIER_SCALE_RUSHER` | 1.50 | 1.20 – 1.80 | Charger death animation length; the "event" feel | Below 1.20: Charger death feels too similar to Drifter — the weight of killing the 35 HP high-damage threat is lost. Above 1.80 (> 1.25s): death sequence stalls wave pacing notably |
| Aggro radius (MVP) | `AGGRO_RADIUS` | 400px | 200px – screen width | At what distance enemies begin chasing Fayde (MVP only — not active at FP) | If too small: enemies passive at spawn, breaking always-pressure feel. If too large: indistinguishable from no-aggro-check (acceptable for FP-style MVP) |

**Cross-system notes:**
- `base_move_speed`, `base_damage`, `base_hp` are NOT tuning knobs for this GDD — they are defined in Enemy Data and must be tuned there.
- `FAYDE_IFRAME_DURATION` (0.5s, from H&D) and `ENEMY_MIN_CONTACT_INTERVAL` are co-tuned: changing either requires checking the safety ratio `FAYDE_IFRAME_DURATION / ENEMY_MIN_CONTACT_INTERVAL > 1.0`.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### Node Architecture

- **AC-EAI-01** — GIVEN an enemy instance is added to the scene tree, WHEN its `process_mode` is read, THEN it equals `PROCESS_MODE_PAUSABLE`.
- **AC-EAI-02** — GIVEN an enemy instance is in the scene tree, WHEN the node tree is inspected, THEN a child `Area2D` node with its own `CollisionShape2D` exists, structurally separate from the root `CollisionShape2D` used for movement.

### Archetype Routing

- **AC-EAI-03a** — GIVEN a Drifter (ID 0) is spawned and `init(0)` is called, WHEN `_archetype`, `_base_damage`, and `_move_speed` are read, THEN `_archetype == SEEKER`, `_base_damage == 8.0`, `_move_speed == 80.0`.
- **AC-EAI-03b** — GIVEN a Charger (ID 1) is spawned and `init(1)` is called, WHEN `_archetype`, `_base_damage`, and `_move_speed` are read, THEN `_archetype == RUSHER`, `_base_damage == 20.0`, `_move_speed == 50.0`.
- **AC-EAI-03c** — GIVEN a Cluster (ID 2) is spawned and `init(2)` is called, WHEN `_archetype`, `_base_damage`, and `_move_speed` are read, THEN `_archetype == SWARMER`, `_base_damage == 4.0`, `_move_speed == 70.0`.

### Phase Gating

- **AC-EAI-04** — GIVEN `_combat_active = false`, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2.ZERO` and no displacement occurs.
- **AC-EAI-05** — GIVEN `_state == DEAD` AND `_combat_active = true`, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2.ZERO` — DEAD takes precedence over `_combat_active`.
- **AC-EAI-06** — GIVEN `_combat_active = false` and a valid Fayde reference, WHEN `combat_started` fires, THEN `_combat_active = true` and the next `_physics_process` call produces non-zero velocity.

### FP Movement

- **AC-EAI-07** — GIVEN enemy at `(0, 0)` and Fayde at `(100, 0)` with `_combat_active = true`, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2(1, 0) × _move_speed`.
- **AC-EAI-08** — GIVEN enemy and Fayde at the exact same position (dir.length() = 0), WHEN `_physics_process(delta)` runs, THEN `velocity` is a valid non-NaN vector — no crash, no NaN propagation. Assertion: `not is_nan(velocity.x) and not is_nan(velocity.y)`.
- **AC-EAI-09** — GIVEN `_dir_last_valid = Vector2(0, 1)` from a prior valid frame, then enemy and Fayde at the same position, WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2(0, 1) × _move_speed` — last valid direction used, not a default axis.
- **AC-EAI-27** — GIVEN `_fayde_ref == null` (Fayde not yet in scene tree), WHEN `_physics_process(delta)` runs, THEN `velocity == Vector2.ZERO` and no null-access error is raised.

### Contact Attack

- **AC-EAI-10** — GIVEN enemy alive in COMBAT_PHASE and Fayde not overlapping, WHEN Fayde's body enters the `Area2D` (`body_entered` fires), THEN `apply_damage(fayde, _base_damage, null, DamageSource.CONTACT)` is called exactly once before any timer elapses.
- **AC-EAI-11** — GIVEN Fayde overlapping and initial hit fired, WHEN `_contact_timer` fires (0.3s) and `_fayde_in_contact == true`, THEN `apply_damage` is called again with the same arguments.
- **AC-EAI-12** — GIVEN Fayde overlapping and timer running, WHEN Fayde's body exits the `Area2D`, THEN `_contact_timer` stops and no further `apply_damage` calls occur after one full `ENEMY_MIN_CONTACT_INTERVAL` duration.
- **AC-EAI-13** — GIVEN the compiled `EnemyAI` class, WHEN `ENEMY_MIN_CONTACT_INTERVAL` is read, THEN its value equals exactly `0.3` (float).
- **AC-EAI-14** — GIVEN `ENEMY_MIN_CONTACT_INTERVAL` and `FAYDE_IFRAME_DURATION` constants, THEN both conditions hold: (1) `ENEMY_MIN_CONTACT_INTERVAL >= 0.3` AND (2) `FAYDE_IFRAME_DURATION / ENEMY_MIN_CONTACT_INTERVAL >= 1.0` — the i-frame window must always outlast one contact interval.

### Death Sequencing

- **AC-EAI-15** — GIVEN an enemy in CHASING with `_contact_timer` running, WHEN `enemy_killed` fires with a matching `instance_id`, THEN in the same frame: `_state == DEAD`, `velocity == Vector2.ZERO`, `_contact_timer` stopped, `$HitArea.monitoring == false`. All four conditions must hold simultaneously.
- **AC-EAI-16** — GIVEN an enemy transitions to DEAD, WHEN the death handler runs, THEN `$AnimationPlayer.is_playing() == true` and the current animation name equals `"death"`.
- **AC-EAI-17** — GIVEN the `"death"` animation is playing, WHEN `animation_finished("death")` fires, THEN `queue_free()` is called — verified by confirming `instance_from_id(enemy.get_instance_id())` returns a valid instance within the same signal handler (node still alive at `animation_finished` moment, freed only at frame end).
- **AC-EAI-29** — GIVEN the AnimationPlayer has no `"death"` animation, WHEN the enemy is killed, THEN a fallback one-shot timer fires and `queue_free()` is called within `BASE_DEATH_DURATION` seconds — enemy node does not persist indefinitely at 0 HP.

### Group Membership

- **AC-EAI-18** — GIVEN an enemy instance after `_ready()`, WHEN `is_in_group("enemy")` is called, THEN returns `true`.
- **AC-EAI-19** — GIVEN an enemy instance after `_ready()`, WHEN `is_in_group("player")` is called, THEN returns `false`.

### Instance ID Guard

- **AC-EAI-28** — GIVEN enemies A and B both alive in COMBAT_PHASE, WHEN `enemy_killed` fires with enemy B's `instance_id`, THEN enemy A's state remains `CHASING`, velocity is unchanged, and no death animation starts on enemy A.

### Dead-Target Guard (cross-H&D)

- **AC-EAI-20** — GIVEN an enemy at `current_hp <= 0` in DEAD state, WHEN `apply_damage` is called on that enemy with any arguments, THEN H&D's dead-target guard returns immediately: `current_hp` unchanged, `damage_taken` not emitted, `enemy_killed` not re-emitted.

### Death Animation Durations (ADVISORY)

- **AC-EAI-21** — GIVEN `BASE_DEATH_DURATION = 0.7s`, WHEN a Cluster `"death"` animation runs, THEN `$AnimationPlayer.get_animation("death").length` equals `0.53s` (±0.03s for frame quantization at 60fps). Evidence: AnimationPlayer inspector screenshot or unit test reading animation length.
- **AC-EAI-22** — GIVEN `BASE_DEATH_DURATION = 0.7s`, WHEN a Drifter `"death"` animation runs, THEN length equals `0.70s` (±0.02s).
- **AC-EAI-23** — GIVEN `BASE_DEATH_DURATION = 0.7s`, WHEN a Charger `"death"` animation runs, THEN length equals `1.05s` (±0.03s).

### Integration

- **AC-EAI-24** — Full contact sequence: GIVEN an alive enemy in COMBAT_PHASE with Fayde not overlapping: (1) Fayde enters → `apply_damage` called once immediately; (2) timer fires at 0.3s, Fayde still overlapping → `apply_damage` called again; (3) Fayde exits → timer stops; (4) after one full interval elapses post-exit → no third call. All 4 steps verified via call counter in one sequential test.
- **AC-EAI-25** — Phase transition during contact: (1) Fayde overlapping, timer running in COMBAT_PHASE; (2) `preparation_started` fires → timer stops, velocity zeros, no damage during PREP phase; (3) `combat_started` fires → phase resumes, new contact correctly re-arms with no leaked timer state.
- **AC-EAI-26** — Kill during overlap: GIVEN Fayde overlapping and timer running, WHEN `enemy_killed` fires for that enemy, THEN `$HitArea.monitoring == false` and no additional `apply_damage` fires — confirmed after one full interval elapses post-kill.

## Open Questions

1. **Stun vs. Slow interface at MVP** — Formula 2 notes that `slow_pct = 1.0` produces zero speed (correct for Stun) but does NOT pause the `_dir_last_valid` direction cache. Stun requires a separate `apply_stun(duration)` method that zeroes velocity AND freezes direction tracking. Status Effects GDD must define this contract before MVP implementation begins. *Owner: Status Effects GDD authoring.*

2. **Arena pixel dimensions for AGGRO_RADIUS** — MVP `AGGRO_RADIUS = 400px` is proposed but unconfirmed. Requires final arena tile dimensions from Wave / Encounter System GDD or Level GDD before the value is locked. Provisional 400px replicates always-chase FP behavior in any arena ≤ 800px wide. *Owner: Wave / Encounter System GDD or Level design spec.*

3. **Visual/Audio section deferred** — Death animation phase timing (crumple: Xf, bloom: Yf, dissolve: Zf), hit flash behavior, and movement SFX were not specified. Must be authored before animation production begins. Requires art director review for crumple → bloom → dissolve frame breakdown. Run `/design-system retrofit design/gdd/enemy-ai.md` to fill this section when art direction is ready. *Owner: Art Director + Audio Director review.*

4. **`_fayde_ref` re-resolution performance** — Rule 4 specifies `get_first_node_in_group("player")` is called each frame when `_fayde_ref == null`. In dense waves (5+ Cluster units), repeated scene-tree queries every frame may be measurable overhead. If profiling shows cost, cache at spawn with a scene-ready signal fallback. *Deferred to profiling after FP implementation.*
