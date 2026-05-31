# ADR-0011: StatusEffectsManager Public API Contract

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Autoload / Status Management) |
| **Knowledge Risk** | MEDIUM — `Dictionary[int, Array[StatusInstance]]` typed dict requires Godot 4.4+ (post-LLM-cutoff); project's 4.6 pin satisfies this |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `Dictionary[int, Array[StatusInstance]]` typed dictionary — added in Godot 4.4 |
| **Verification Required** | Confirm `Dictionary[int, Array[StatusInstance]]` typed declaration is accepted by the Godot 4.6 GDScript parser before StatusEffectsManager implementation begins |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — SEM is Autoload #7; registration order constrains safe `_ready()` connection points. ADR-0003 (Accepted) — `apply_status()` and `has_status()` are Pattern 2 (direct method call); signals are Pattern 1. ADR-0004 (Accepted) — tick timer uses float accumulator in `_process(delta)`, not `SceneTree.create_timer()` or Timer nodes. ADR-0006 (Accepted) — `GameEnums.BaseStatus` is the authoritative type for all `status_type` parameters. ADR-0007 (Accepted) — SEM calls `HealthAndDamage.apply_damage()` and `apply_heal()` for tick effects; H&D is the HP authority. ADR-0009 (Proposed, being Accepted this session) — SEM calls `SpellCastingEffects.get_stat_bonus()` for wave-scoped stat bonuses; SEM must not hold its own SpellEffect cache. |
| **Enables** | StatusEffectsManager MVP implementation stories; Enemy AI MVP implementation stories (Enemy AI must expose `apply_speed_modifier()`, `apply_stun()`, and `is_alive()` per this ADR) |
| **Blocks** | StatusEffectsManager MVP story implementation; Enemy AI implementation story creation (interface spec incomplete until this ADR is Accepted) |
| **Ordering Note** | ADR-0009 must be Accepted before StatusEffectsManager implementation stories begin — SEM's stat queries depend on SC&E's stat broker contract. |

## Context

### Problem Statement
StatusEffectsManager (Autoload #7) is the tick-timing authority for all persistent Prana-triggered combat conditions. Five systems interact with it: SC&E calls `apply_status()` on every spell hit and `check_and_apply_shatter()` before every direct damage delivery; SEM calls back into H&D's `apply_damage()`/`apply_heal()` on each tick; Enemy AI nodes must expose speed-modifier and stun interfaces that SEM pushes to; and the VFX pipeline listens to SEM's signals.

No ADR documents this contract. Without one:
- `architecture.md` defines a stale 3-arg `apply_status()` and per-status `is_frozen()`/`is_blinded()` methods — inconsistent with the GDD's 4-arg unified API.
- Enemy AI stories cannot be created without knowing the required `apply_speed_modifier()` and `apply_stun()` interface.
- `check_and_apply_shatter()` is entirely absent from `architecture.md`.
- No registry entry prevents a future system from creating its own SpellEffect cache to read status durations directly (violating ADR-0009).

### Constraints
- StatusEffectsManager is Autoload #7. Per ADR-0002 Rule 3, it may not call higher-registered Autoloads (SC&E #9) during `_ready()`. Stat queries via `get_stat_bonus()` are made during gameplay execution, not `_ready()` — no ordering violation.
- SEM must NOT subscribe to `CombinationResolution.combo_resolved` for SpellEffect caching. ADR-0009 establishes SC&E as the sole SpellEffect cache owner. SEM reads stat bonuses via `SpellCastingEffects.get_stat_bonus()` (Pattern 2 call).
- Tick timing uses float accumulators in `_process(delta)` — no `SceneTree.create_timer()`, no Timer nodes (ADR-0004).
- All `status_type` parameters use `GameEnums.BaseStatus` — per ADR-0006.
- `process_mode = PROCESS_MODE_PAUSABLE` — tick timers and duration counters halt on `get_tree().paused = true`.

### Requirements
- Single authoritative public API for all status application, query, and conditional Shatter logic
- 4-arg `apply_status()` with `spell_base_damage` default parameter — Burn ticks require the captured base damage value
- Unified `has_status()` — replaces per-status `is_frozen()`/`is_blinded()` from `architecture.md`; scales to all current and future status types without new method additions
- Shatter query exposed as `check_and_apply_shatter()` — SC&E calls this before every DIRECT `apply_damage()` call
- Enemy AI node interface requirements documented — prerequisite for Enemy AI story creation
- Signal contract specified — VFX pipeline and CombatHUD connect to these signals

## Decision

StatusEffectsManager exposes three public methods and four signals. All other systems interact with SEM exclusively through this interface.

### Public Methods

```gdscript
## Call on every spell hit that carries a base_status. Validates target scope,
## handles re-apply (reset duration + spell_base_damage), starts tick accumulator.
## spell_base_damage defaults 0.0 for non-DoT statuses (Freeze, Blind, Stun, Regen, Chill, Stagger).
func apply_status(
    target: Node,
    status_type: GameEnums.BaseStatus,
    duration: float,
    spell_base_damage: float = 0.0
) -> void

## Returns true if target has an active StatusInstance of status_type.
## Returns false if the target has no registered statuses or status_type is not present.
## O(N) where N = active statuses on the target (max 7). Call sparingly in tight loops.
func has_status(target: Node, status_type: GameEnums.BaseStatus) -> bool

## Called by SC&E before every DIRECT apply_damage() call.
## Returns base_damage × SHATTER_MULTIPLIER (1.25) if the target has an active FREEZE
## StatusInstance; returns base_damage unchanged otherwise. Emits shatter_triggered(target)
## when Shatter fires. Freeze is NOT consumed — it runs to its full duration.
func check_and_apply_shatter(target: Node, base_damage: float) -> float
```

### Signals

```gdscript
## Emitted on every apply_status() call that creates or re-applies a StatusInstance.
signal status_applied(target: Node, status_type: GameEnums.BaseStatus, duration: float)

## Emitted when a StatusInstance's duration_remaining reaches 0 and is removed.
## NOT emitted during wave-clear (preparation_started) or enemy death cleanup.
signal status_expired(target: Node, status_type: GameEnums.BaseStatus)

## Emitted when Burn Contagion transfers from a dying enemy to a living one.
signal burn_contagion_triggered(dying_enemy_position: Vector2, to_target: Node)

## Emitted when check_and_apply_shatter() fires the Shatter bonus.
signal shatter_triggered(target: Node)
```

### Enemy AI Node Interface Requirements

SEM pushes speed and stun commands directly onto enemy node instances. All `EnemyInstance` scripts **must** expose:

```gdscript
## Called by SEM on Freeze/Chill apply and expiry.
## multiplier = 0.50 for Freeze; 0.85 for Chill (1.0 - CHILL_SLOW_PCT); 1.0 on expiry.
## Enemy AI stores _speed_multiplier and applies it in _physics_process().
func apply_speed_modifier(multiplier: float) -> void

## Called by SEM on Stun and Stagger apply. Zeroes velocity and freezes direction
## tracking for the given duration. Self-terminating in Enemy AI — SEM tracks the
## StatusInstance for expiry signal and wave-clear cleanup only. No second call on expiry.
func apply_stun(duration: float) -> void
```

All valid target node types (EnemyInstance, PlayerController) **must** expose:

```gdscript
## Returns true when current_hp > 0. Called by SEM at the start of apply_status()
## to prevent StatusInstance creation on dead targets.
func is_alive() -> bool
```

### Architecture Diagram

```
SC&E ──apply_status(target, type, dur, base_dmg)──────────────────▶ StatusEffectsManager
SC&E ──check_and_apply_shatter(target, dmg)◀──────────────────────┤
      └─ returns dmg × 1.25 (FREEZE active) or dmg unchanged       │
                                                                    │ _process(delta)
StatusEffectsManager ──apply_damage(target, tick, null, DOT)───────┤──▶ HealthAndDamage
StatusEffectsManager ──apply_heal(fayde, tick_heal)────────────────┤──▶ HealthAndDamage
                                                                    │
StatusEffectsManager ──apply_speed_modifier(multiplier)────────────┤──▶ EnemyInstance
StatusEffectsManager ──apply_stun(duration)────────────────────────┤──▶ EnemyInstance
                                                                    │
HealthAndDamage.enemy_killed ──────────────────────────────────────┤──▶ _on_enemy_killed()
GameStateManager.preparation_started ──────────────────────────────┘──▶ _on_preparation_started()

StatusEffectsManager ──status_applied(target, type, dur)───▶ VFX / CombatHUD
StatusEffectsManager ──status_expired(target, type)────────▶ VFX / CombatHUD
StatusEffectsManager ──burn_contagion_triggered(pos, to)───▶ VFX
StatusEffectsManager ──shatter_triggered(target)───────────▶ VFX
```

### API Supersessions (from architecture.md)

This ADR supersedes the following stale entries in `docs/architecture/architecture.md`:

| Old (architecture.md) | New (this ADR) | Reason |
|---|---|---|
| `apply_status(target, type, duration)` | `apply_status(target, type, duration, spell_base_damage: float = 0.0)` | Burn requires captured base damage; 4th param added in GDD authoring after architecture.md was written |
| `is_frozen(target) → bool` | `has_status(target, GameEnums.BaseStatus.FREEZE) → bool` | Unified API; per-status helpers don't scale to CHILL/STAGGER/future types |
| `is_blinded(target) → bool` | `has_status(target, GameEnums.BaseStatus.BLIND) → bool` | Same as above |
| *(missing)* | `check_and_apply_shatter(target, base_damage) → float` | Added in GDD authoring; architecture.md predates Shatter design |

## Alternatives Considered

### Alternative B: Per-Status Query Methods
- **Description**: Retain `is_frozen(target)`, `is_blinded(target)`, `is_stunned(target)` as individual boolean methods matching architecture.md's original spec.
- **Pros**: Call sites are more readable — `StatusEffectsManager.is_frozen(target)` vs `has_status(target, FREEZE)`.
- **Cons**: Requires a new method for every new status type. CHILL and STAGGER (already needed at MVP scope) would each need dedicated helpers. Any future VS-scope type adds another. Each method is a one-liner wrapper around the same dictionary lookup.
- **Rejection Reason**: Does not scale. The GDD explicitly chose `has_status()` as the unified query; the per-method form violates that decision and multiplies the public API surface with no architectural benefit.

### Alternative C: Event-Driven Status Query (No has_status)
- **Description**: SEM exposes no synchronous query method. Systems needing to know whether a target has a status maintain their own cache by listening to `status_applied` / `status_expired` signals.
- **Pros**: SC&E would have no runtime dependency on SEM for Shatter checks.
- **Cons**: `check_and_apply_shatter()` must return a value — signals cannot carry return values (ADR-0003). Signal-based caching introduces one-frame lag and a duplicate status-tracking burden in SC&E. Each listener becomes a second owner of active-status state, violating the single-owner principle ADR-0009 established.
- **Rejection Reason**: Incompatible with ADR-0003 (void-return signals). Creates duplicate state ownership explicitly prohibited by ADR-0009's stance.

## Consequences

### Positive
- Resolves the API mismatch between `architecture.md` and `status-effects.md` — a single authoritative source now exists
- `has_status()` scales to all current (BURN, FREEZE, BLIND, STUN, REGEN, CHILL, STAGGER) and future status types without new method additions
- Enemy AI story creation is unblocked — `apply_speed_modifier()` and `apply_stun()` are formally specified
- `check_and_apply_shatter()` is registered as an interface contract — `/architecture-review` can flag callers that bypass it and call `has_status(FREEZE)` directly
- `is_alive()` requirement on target nodes is documented — prevents `apply_status` races on same-frame death events

### Negative
- SC&E must call `check_and_apply_shatter()` before every DIRECT `apply_damage()` call — one additional method dispatch per spell hit. Cost is O(N) dictionary lookup, N ≤ 7; negligible at combat scale.
- Enemy AI implementation stories are blocked until Enemy AI GDD formally documents `apply_speed_modifier()` and `apply_stun()`. This ADR is the trigger for that cross-GDD update.

### Risks
- **Risk**: A developer adds `is_frozen()` or similar per-status shortcuts alongside `has_status()`, duplicating the query surface.
  **Mitigation**: Registered forbidden_pattern `per_status_query_helpers` bans this. `has_status()` is the sole registered query interface.
- **Risk**: SC&E's `apply_status()` call omits `spell_base_damage` for Burn applications, causing zero-damage DoT ticks.
  **Mitigation**: SC&E GDD's cross-GDD update flag requires passing `effective_base` as the 4th argument for Burn. This ADR makes the omission a contract violation enforceable in code review.
- **Risk**: `Dictionary[int, Array[StatusInstance]]` typed dict syntax is post-LLM-cutoff; may cause confusion if Godot version is wrong.
  **Mitigation**: AC-0011-01 verifies this declaration is accepted by the Godot 4.6 parser before implementation.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| status-effects.md | Rule 4 — `apply_status(target, status_type, duration, spell_base_damage = 0.0)` public entry point | Formalizes 4-arg signature as authoritative contract; supersedes 3-arg version in architecture.md |
| status-effects.md | Rule 4a — `has_status(target, status_type) → bool` | Registers as the sole status query interface; bans per-status helpers (`is_frozen`, etc.) |
| status-effects.md | Rule 10 — `check_and_apply_shatter(target, base_damage) → float` | Registers as the Shatter authority interface; SC&E must call this, not `has_status()` directly |
| status-effects.md | Interactions table — signals `status_applied`, `status_expired`, `burn_contagion_triggered`, `shatter_triggered` | Formalizes all four signal signatures as architectural contracts |
| status-effects.md | Rule 4 steps 5–8, Rule 7 — `apply_speed_modifier(float)`, `apply_stun(float)` on Enemy AI nodes | Documents the cross-system interface requirement on EnemyInstance; unblocks Enemy AI story creation |
| status-effects.md | Edge Case 1 / Rule 4 step 1a — `is_alive() → bool` required on all target node types | Formalizes the alive-check prerequisite |
| enemy-ai.md | Must expose `apply_speed_modifier(float)` (cross-GDD flag in status-effects.md Dependencies) | This ADR is the authoritative source; Enemy AI GDD must add this to its Interface Contracts |
| spell-casting-effects.md | Formula 3 Step 5 must call `check_and_apply_shatter()`, not `target.has_status(STATUS_FREEZE)` | Formalizes the requirement; SC&E GDD cross-GDD update flag applies |
| health-damage.md | `apply_damage(target, tick_dmg, null, DamageSource.DOT)` and `apply_heal(fayde, tick_heal)` are tick output methods | Confirms SEM's outbound call pattern matches H&D's registered interface (ADR-0007) |

## Performance Implications
- **CPU**: `apply_status()` — dictionary lookup + array scan for re-apply check. O(N), N ≤ 7 active statuses per target. Called only on spell hit, not per frame.
- **CPU**: `has_status()` — same O(N) per call. Called by `check_and_apply_shatter()` once per DIRECT hit.
- **CPU**: `_process(delta)` tick loop — O(T) total active StatusInstances. At maximum (15 enemies × 7 statuses = 105 instances): 105 float comparisons per frame. Negligible at 60fps target.
- **Memory**: `Dictionary[int, Array[StatusInstance]]` — bounded by active enemies × status types. Max ~105 StatusInstances, ~100–200 bytes each ≤ ~21KB. Unmeasurable.
- **Load Time**: No impact — `_ready()` initializes an empty dictionary.
- **Network**: N/A

## Migration Plan
New project — no existing code to migrate. `architecture.md` API Reference section must be updated (done alongside this ADR) to prevent developers implementing the stale 3-arg signature.

## Validation Criteria
1. **AC-0011-01** — `Dictionary[int, Array[StatusInstance]]` typed declaration is accepted by the Godot 4.6 GDScript parser with no error (pre-implementation check).
2. **AC-0011-02** — `apply_status(enemy, BURN, 2.0, 20.0)` creates a StatusInstance with `spell_base_damage = 20.0`; `apply_status(enemy, FREEZE, 2.0)` creates one with `spell_base_damage = 0.0` (default applied).
3. **AC-0011-03** — `has_status(target, FREEZE)` returns `true` when a FREEZE StatusInstance is active; `false` after expiry. Replaces `is_frozen()` validation from architecture.md.
4. **AC-0011-04** — `check_and_apply_shatter(frozen_enemy, 16.0)` returns `20.0` (16 × 1.25) and emits `shatter_triggered`; called on an unfrozen enemy returns `16.0` unchanged and does not emit.
5. **AC-0011-05** — `apply_speed_modifier(0.50)` is called on an EnemyInstance when Freeze is applied; `apply_speed_modifier(1.0)` is called when Freeze expires. No call on re-apply (multiplier already applied).
6. **AC-0011-06** — `apply_stun(0.8)` is called on an EnemyInstance exactly once when Stun is applied. No second call on expiry.
7. **AC-0011-07** — `is_alive()` returns `true` for `current_hp > 0`; `false` for `current_hp = 0`. `apply_status()` returns immediately without creating a StatusInstance when `is_alive()` is false.

## Related Decisions
- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — SEM is Autoload #7; registration order constrains `_ready()` connection points
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — all SEM outbound communication uses Pattern 1 (signal) or Pattern 2 (direct method call)
- [ADR-0004: Float Accumulator Timer Pattern](adr-0004-float-accumulator-timer-pattern.md) — SEM tick timing uses `_process(delta)` float accumulators, not Timer nodes
- [ADR-0006: GameEnums Pure Container](adr-0006-game-enums-pure-container.md) — `GameEnums.BaseStatus` is the authoritative enum type for all `status_type` parameters
- [ADR-0007: HealthAndDamage Autoload Singleton](adr-0007-health-damage-autoload-singleton.md) — SEM calls `apply_damage()` and `apply_heal()` for tick effects; H&D owns HP math
- [ADR-0009: SpellCastingEffects Wave-Scoped Stat Broker](adr-0009-spell-casting-effects-stat-broker.md) — SEM calls `get_stat_bonus()` for duration/damage modifiers; SEM must not hold its own SpellEffect cache
- [ADR-0010: Player and Enemy Group Convention](adr-0010-player-group-convention.md) — SEM uses `is_in_group()` for target scope validation (Regen = "player"; Burn/Freeze/etc = "enemy")
- [design/gdd/status-effects.md](../../design/gdd/status-effects.md) — primary GDD defining all SEM behavior, formulas, and acceptance criteria
- [design/gdd/spell-casting-effects.md](../../design/gdd/spell-casting-effects.md) — SC&E is the sole `apply_status` caller and `check_and_apply_shatter` caller
- [design/gdd/enemy-ai.md](../../design/gdd/enemy-ai.md) — Enemy AI must expose `apply_speed_modifier()` and `apply_stun()`; this ADR unblocks Enemy AI implementation stories
