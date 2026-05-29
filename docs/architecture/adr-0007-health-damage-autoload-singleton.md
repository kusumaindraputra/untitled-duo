# ADR-0007: HealthAndDamage as Autoload Singleton

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (HP management, Damage pipeline) |
| **Knowledge Risk** | LOW — Dictionary, `instance_from_id()`, `roundi()`, `clamp()` all unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `health-damage.md`, `enemy-ai.md`, `wave-encounter-system.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Verify `instance_from_id()` returns null (not crash) for a freed node's ID in a minimal GUT test |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — H&D is Autoload #6; must be after GSM (3); must be before SEM (7) |
| **Enables** | ADR-0003 (signal contracts); StatusEffectsManager (SEM calls H&D); SpellCastingEffects (calls H&D); EnemyInstance (calls H&D) |
| **Blocks** | StatusEffectsManager, SpellCastingEffects, EnemyInstance, WaveManager implementation |
| **Ordering Note** | Must be Accepted before any story involving HP, damage, or healing |

## Context

### Problem Statement

Fayde and every enemy in the game need HP pools. There are two architectural options: (a) per-node HP (each EnemyInstance holds its own `current_hp` variable), or (b) central HP registry (HealthAndDamage Autoload holds all HP in a dictionary). The damage pipeline also needs to apply elemental multipliers, i-frame checks, clamps, and emit signals — this logic must live in exactly one place.

**Resolved open questions (from architecture.md QQ-03, QQ-04):**
- QQ-03: Enemy HP registration contract — WaveManager calls `register_enemy()` before `add_child()`
- QQ-04: EnemyType.tres scene reference — `EnemyType` gets a `scene: PackedScene` field; WaveManager spawns via this field

### Constraints

- Engine: Godot 4.6, GDScript
- Up to 10 enemies per wave at First Playable
- `enemy_killed` signal must fire from one authoritative source (H&D, not EnemyInstance)
- Fayde's HP pool must persist across wave transitions within a run (not reset between waves)
- StatusEffectsManager must call `apply_damage()` and `apply_heal()` on H&D (Autoload pattern, not per-node)
- Player invincibility frame (i-frame) check must be in the damage pipeline, not in every caller

### Requirements

- Single `apply_damage()` entry point for all damage sources (DIRECT, DOT, CONTACT)
- Single `apply_heal()` entry point for all healing (Regen ticks, Injury Bloom)
- Enemy HP registered and unregistered by a clear contract
- `enemy_killed` signal includes `instance_id`, `type_id`, and `prana_affiliation` for WaveManager and StatusEffectsManager
- i-frame window managed by H&D (not by EnemyInstance or PlayerController)
- All HP values stored as `float` internally; damage numbers exposed as `int` (via `roundi()`)

## Decision

**HealthAndDamage is Autoload #6.** It is the sole owner of all HP state for the session.

### Data Structures

```gdscript
class_name HealthAndDamage
extends Node

# ── Fayde HP ──────────────────────────────────────────────────────────────────
var _fayde_max_hp: float          # = EnemyData default or tuning knob (100.0)
var _fayde_current_hp: float
var _iframe_active: bool = false
var _iframe_timer: float = 0.0    # float accumulator (ADR-0004)
const FAYDE_IFRAME_DURATION: float = 0.5

# ── Enemy HP registry ─────────────────────────────────────────────────────────
var _enemy_registry: Dictionary[int, EnemyHPInstance] = {}
# Key: node.get_instance_id()   Value: EnemyHPInstance

# ── HP zone (for audio/visual feedback) ────────────────────────────────────────
var _current_zone: GameEnums.HPZone = GameEnums.HPZone.FULL
```

```gdscript
class_name EnemyHPInstance
extends RefCounted

var max_hp: float
var current_hp: float
var type_id: int
var is_dead: bool = false
var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
```

### Public API

```gdscript
# ── Registration (called by WaveManager, NOT by EnemyInstance._ready()) ───────
func register_enemy(enemy: Node, type_id: int) -> void
func unregister_enemy(instance_id: int) -> void  # called internally on enemy_killed

# ── Damage and healing ────────────────────────────────────────────────────────
func apply_damage(target: Node, base_damage: float,
                  element: GameEnums.DamageClass,
                  source: GameEnums.DamageSource) -> void
func apply_heal(target: Node, heal_amount: float) -> void  # negative → push_error + no-op
func force_end_iframe_window() -> void  # TEST SEAM ONLY — never call from gameplay

# ── Signals ───────────────────────────────────────────────────────────────────
signal damage_taken(target: Node, final_damage: int, current_hp: int)
signal health_restored(target: Node, healed_amount: int, current_hp: int)
signal player_died()                  # fires exactly once per run
signal enemy_killed(instance_id: int, type_id: int,
                    prana_affiliation: GameEnums.DamageClass)  # NONE for neutral
signal heavy_hit(target: Node, final_damage: int)  # final_damage >= heavy_hit_threshold
signal player_hp_zone_changed(zone: GameEnums.HPZone)
```

### `apply_damage()` Pipeline

```gdscript
func apply_damage(target: Node, base_damage: float,
                  element: GameEnums.DamageClass,
                  source: GameEnums.DamageSource) -> void:

    # Step 1a — i-frame check (player only, CONTACT damage only)
    if target.is_in_group(&"player") and source == GameEnums.DamageSource.CONTACT:
        if _iframe_active:
            return  # i-frame absorbs hit, Injury Bloom does NOT fire

    # Step 1b — elemental multiplier (2× if element matches target's affiliation)
    var multiplier: float = _get_elemental_multiplier(target, element)

    # Step 2 — final_damage formula
    # final_damage = roundi(base_damage * multiplier)
    # Clamp: 0 < final_damage <= target_current_hp (no overkill; no negative damage)
    var final_damage: int = roundi(base_damage * multiplier)
    final_damage = clampi(final_damage, 0, _get_current_hp(target))

    # Step 3 — apply to HP pool
    if target.is_in_group(&"player"):
        _fayde_current_hp -= final_damage
        _start_iframe_window_if_contact(source)
    else:
        _enemy_registry[target.get_instance_id()].current_hp -= final_damage

    # Step 4 — emit signals
    emit_signal("damage_taken", target, final_damage, _get_current_hp(target))
    if final_damage >= heavy_hit_threshold:
        emit_signal("heavy_hit", target, final_damage)
    _check_hp_zone_change()

    # Step 5 — death check
    if _get_current_hp(target) <= 0:
        if target.is_in_group(&"player"):
            emit_signal("player_died")
        else:
            var inst := _enemy_registry[target.get_instance_id()]
            inst.is_dead = true
            emit_signal("enemy_killed", target.get_instance_id(), inst.type_id, inst.prana_affiliation)
            _enemy_registry.erase(target.get_instance_id())
```

### WaveManager Registration Contract

WaveManager must follow this exact sequence when spawning an enemy:

```gdscript
# ── CORRECT: register before add_child ────────────────────────────────────────
func _spawn_enemy(enemy_type: EnemyType) -> void:
    var enemy: EnemyInstance = enemy_type.scene.instantiate()
    HealthAndDamage.register_enemy(enemy, enemy_type.id)  # ← BEFORE add_child
    _arena.add_child(enemy)                               # ← AFTER register

# ── WRONG: register in EnemyInstance._ready() ─────────────────────────────────
# This is a race condition: EnemyInstance._ready() runs after add_child(); if any
# system reads H&D for this enemy between add_child() and _ready(), the entry is missing.
```

**Why before `add_child()`:** `register_enemy()` creates the `EnemyHPInstance` in the dictionary. After `add_child()`, `enemy._ready()` fires, which connects to GSM and other signals. If any signal handler tries to read HP before `_ready()` finishes (unlikely but possible in multi-signal stacks), registration must already be complete.

### EnemyType.tres Scene Reference (resolves QQ-04)

```gdscript
class_name EnemyType
extends Resource

@export var id: int = 0
@export var display_name: String = ""
@export var archetype: GameEnums.EnemyArchetype = GameEnums.EnemyArchetype.SEEKER
@export var max_hp: float = 30.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var attack_rate: float = 0.3
@export var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
@export var scene: PackedScene  # ← EnemyInstance scene for this type
```

WaveManager spawns via `EnemyType.scene.instantiate()`. EnemyCatalog owns the four EnemyType resources. No separate scene map is needed.

### i-Frame Window Management

i-frames apply only to `DamageSource.CONTACT` hits on the player. The window is `FAYDE_IFRAME_DURATION = 0.5s` as a float accumulator (ADR-0004).

```gdscript
func _process(delta: float) -> void:
    if _iframe_active:
        _iframe_timer += delta
        if _iframe_timer >= FAYDE_IFRAME_DURATION:
            _iframe_active = false
            _iframe_timer = 0.0
```

### Run Reset

On `GSM.run_started`:

```gdscript
func _on_run_started() -> void:
    _fayde_current_hp = _fayde_max_hp
    _enemy_registry.clear()
    _iframe_active = false
    _iframe_timer = 0.0
    _current_zone = GameEnums.HPZone.FULL
```

## Alternatives Considered

### Alternative B: Per-Enemy HP (EnemyInstance owns its own HP)

- **Description**: Each `EnemyInstance` has `var current_hp: float` and `var max_hp: float`. Damage is applied directly by calling `enemy.take_damage(amount)`.
- **Pros**: HP co-located with the entity; more object-oriented pattern; easier to understand in isolation
- **Cons**: `enemy_killed` signal must be emitted by EnemyInstance — but other systems (WaveManager, StatusEffectsManager) must disconnect from each enemy individually; requires a group lookup or direct reference each time damage is applied; if `enemy_killed` fires before `queue_free()`, SEM must handle possible double-decrement; impossible to call `apply_damage()` from StatusEffectsManager without a direct reference to the enemy node
- **Rejection Reason**: i-frame logic duplicated in every caller; `enemy_killed` ownership ambiguous; SEM cannot call `take_damage()` on arbitrary targets without holding direct enemy references. Central registry eliminates all these coupling problems.

### Alternative C: Damage Events via Signal (deferred pipeline)

- **Description**: Callers emit a `damage_requested` signal with target + amount; H&D listens and processes. All callers (SC&E, SEM, EnemyInstance) communicate via signals only.
- **Pros**: Maximum decoupling — no system calls methods on H&D directly
- **Cons**: Godot signals are void-return. Callers can't know if damage actually applied (i-frame absorption, dead target) without a separate "damage result" signal. Adds two round-trip signal hops for every damage event. The "result" signal also requires target correlation (which incoming damage request does this result correspond to?).
- **Rejection Reason**: Impractical. Direct method call for an explicit owned operation is the correct pattern per ADR-0003 Pattern 2.

## Consequences

### Positive

- One `apply_damage()` call for all sources — i-frame, elemental multiplier, clamp, signals all applied consistently
- `enemy_killed` signal fires from one place with complete data (instance_id, type_id, affiliation)
- StatusEffectsManager can apply DoT without holding enemy node references (uses `instance_from_id()` to validate target still exists)
- H&D is independently testable in GUT with a fake enemy node — no real scene tree required

### Negative

- Dictionary lookup per `apply_damage()` call — negligible cost but not zero
- `instance_from_id()` returns null for freed nodes — callers must guard against this in edge cases (H&D handles internally)
- WaveManager must follow the registration contract precisely — a forgotten `register_enemy()` produces a silent miss on damage with no crash, just a push_error

### Risks

- **Risk**: StatusEffectsManager fires a DOT tick after the enemy is already dead (race between `enemy_killed` and the next `_process()` tick).
  **Mitigation**: H&D's `apply_damage()` pipeline checks `is_dead` on the EnemyHPInstance before applying. If `_enemy_registry` has already been erased for this instance_id, `instance_from_id()` returns null and the call is a no-op.
- **Risk**: WaveManager forgets to call `register_enemy()` before `add_child()`.
  **Mitigation**: `apply_damage()` uses `push_error()` if the target is an enemy not in the registry. Catches this at development time without crashing.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| health-damage.md | Single authoritative damage pipeline; all modifiers applied in order | `apply_damage()` as sole entry point; pipeline steps 1–5 documented |
| health-damage.md | Player i-frame window (0.5s) | `_iframe_active` + float accumulator (ADR-0004); absorbs CONTACT only |
| health-damage.md | `enemy_killed` signal with instance_id, type_id, prana_affiliation | Emitted from central pipeline at step 5; registry erased immediately after |
| health-damage.md | HP zone tracking for danger audio/visual | `_check_hp_zone_change()` emits `player_hp_zone_changed(zone)` |
| status-effects.md | StatusEffectsManager calls `apply_damage(DOT)` and `apply_heal()` | H&D is an Autoload callable from SEM without direct enemy reference |
| enemy-ai.md | EnemyInstance deals CONTACT damage via `apply_damage(CONTACT)` | Single pipeline handles CONTACT damage with i-frame check |
| wave-encounter-system.md | WaveManager knows when all enemies are dead | `enemy_killed` signal → WaveManager decrements `_enemies_alive` |

## Performance Implications

- **CPU**: Dictionary lookup by `int` key — O(1), negligible; `instance_from_id()` — O(1), Godot-internal
- **Memory**: Dictionary of up to 10 `EnemyHPInstance` at First Playable — negligible
- **Load Time**: H&D `_ready()` only connects signals — no resource loading

## Validation Criteria

1. **AC-0007-01**: `apply_damage()` with i-frame active and `DamageSource.CONTACT` — HP does not decrease; no signal fires
2. **AC-0007-02**: `apply_damage()` to a dead enemy (already in `is_dead = true` state) — no HP change, no duplicate `enemy_killed` signal
3. **AC-0007-03**: `register_enemy()` not called before `apply_damage()` — `push_error()` fires; no crash; no HP change
4. **AC-0007-04**: `instance_from_id()` on a freed node's ID — returns null; `apply_damage()` exits cleanly with a `push_error()`
5. **AC-0007-05**: Same-frame kill+death (boss_defeated + player_died) — `player_died` resolves immediately (DEATH_SCREEN); `boss_defeated` via `call_deferred` is rejected as invalid transition. Loss preserved.

## Related Decisions

- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — H&D is Autoload #6; SEM (#7) depends on it
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — Cross-System Interaction Map; `damage_taken`, `enemy_killed` signal contracts
- [ADR-0004: Float Accumulator Timer Pattern](adr-0004-float-accumulator-timer-pattern.md) — i-frame timer uses accumulator pattern
- [ADR-0006: GameEnums](adr-0006-game-enums-pure-container.md) — `DamageClass`, `DamageSource`, `HPZone` all from GameEnums
- [docs/architecture/architecture.md](../architecture.md) — Data Flow Scenario 3 (same-frame death priority); Module Ownership (HealthAndDamage, WaveManager)
