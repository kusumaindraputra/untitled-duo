# ADR-0006: GameEnums as Pure Enum Container

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (GDScript / Resource Serialization) |
| **Knowledge Risk** | MEDIUM — `class_name` global access is stable; `.tres` enum serialization behavior (int vs string) must be verified against Godot 4.6 before authoring `.tres` files |
| **References Consulted** | `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/breaking-changes.md`, `prana-data.md` (Implementation Notes) |
| **Post-Cutoff APIs Used** | None — `class_name`, `extends RefCounted`, enum syntax unchanged |
| **Verification Required** | Create a throwaway Resource with `@export var damage_class: GameEnums.DamageClass`, save as `.tres`, inspect in text editor — verify integer serialization before authoring any real `.tres` files |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — GameEnums is the deepest foundation; nothing depends on it |
| **Enables** | Every system in the project (all enums shared here) |
| **Blocks** | Any coding that uses DamageClass, DamageSource, BaseStatus, GameState, or any other shared enum |
| **Ordering Note** | `game_enums.gd` must be created before any other `.gd` file that references these enum types |

## Context

### Problem Statement

Ten game systems need access to the same set of enum types: `DamageClass`, `DamageSource`, `BaseStatus`, `CastAnimation`, `VfxBurstShape`, `HPZone`, `GameState`, `RunOutcome`, `EnemyArchetype`, `WaveState`, `EnemyState`. Without a canonical location, these enums will be defined redundantly in each system's file, producing: (1) name collisions and cast errors when values cross system boundaries, (2) `.tres` Resource files serializing the same enum with different integer assignments, (3) circular import chains when System A imports System B to get an enum that System B imports System C to use.

### Constraints

- Godot 4.6: `class_name` declarations make the class globally accessible — no `preload()` needed in any consumer
- `.tres` Resources serialize `@export enum` properties as integers (Godot 4.x) — enum values must have stable integer assignments to prevent silent corruption when enum order changes
- Prana Data GDD (Implementation Notes): "No `extends` beyond `RefCounted`, no `@onready`, no `preload` or `load` from any other game script. It is a pure enum container. Any import introduced creates a circular dependency risk for every system in the project."
- GameEnums must NOT be an Autoload — it has no runtime state, no `_ready()` needs, and registering it as an Autoload wastes an Autoload slot on a static class

### Requirements

- All shared enum types defined in one file, one place
- No runtime initialization required (no `_ready()`)
- No import chain — `class_name` global access only
- `.tres` serialization safety — explicit integer assignments on all enum constants

## Decision

`src/data/game_enums.gd` uses `class_name GameEnums extends RefCounted`. It is **NOT an Autoload**. It contains only enum definitions with explicit integer assignments.

```gdscript
class_name GameEnums
extends RefCounted

# ── Damage and targeting ──────────────────────────────────────────────────────
enum DamageClass  { NONE = -1, FIRE = 0, SHADOW = 1, LIGHTNING = 2, ICE = 3, NATURE = 4 }
enum DamageSource { DIRECT = 0, DOT = 1, CONTACT = 2 }

# ── Status effects ────────────────────────────────────────────────────────────
enum BaseStatus   { BURN = 0, BLIND = 1, STUN = 2, FREEZE = 3, REGENERATE = 4,
                    CHILL = 5, STAGGER = 6 }

# ── HP state zones (for audio/visual danger feedback) ─────────────────────────
enum HPZone       { FULL = 0, CAREFUL = 1, DESPERATE = 2 }

# ── Game state machine ────────────────────────────────────────────────────────
enum GameState    { MAIN_MENU = 0, PREPARATION_PHASE = 1, COMBAT_PHASE = 2,
                    PAUSED = 3, RUN_SUMMARY = 4, DEATH_SCREEN = 5 }

# ── Run outcome ───────────────────────────────────────────────────────────────
enum RunOutcome   { NONE = 0, WIN = 1, LOSS = 2 }

# ── Enemy archetypes ──────────────────────────────────────────────────────────
enum EnemyArchetype { SEEKER = 0, RUSHER = 1, SWARMER = 2, BOSS = 3 }

# ── Enemy AI state ────────────────────────────────────────────────────────────
enum EnemyState   { IDLE = 0, PURSUING = 1, ATTACKING = 2, STUNNED = 3, DEAD = 4 }

# ── Wave state ────────────────────────────────────────────────────────────────
enum WaveState    { IDLE = 0, WAVE_ACTIVE = 1, WAVE_COMPLETE = 2 }

# ── Visual and audio routing ──────────────────────────────────────────────────
enum CastAnimation { CAST_THRUST = 0, CAST_REACH = 1, CAST_SNAP = 2,
                     CAST_PUSH = 3, CAST_BLOOM = 4 }
enum VfxBurstShape { BURST_FLAME = 0, BURST_SPIRAL = 1, BURST_LIGHTNING = 2,
                     BURST_CRYSTAL = 3, BURST_VINE = 4 }
```

### Forbidden Patterns

```gdscript
# ── FORBIDDEN: anything other than enum declarations ────────────────────────
extends Node           # WRONG — must be RefCounted (no scene tree integration)
@onready var foo       # WRONG — RefCounted has no _ready()
var state = GameEnums  # WRONG — cannot hold an instance

preload("res://src/...")  # WRONG — any import creates circular dep risk
load("res://src/...")     # WRONG — same

@export var bad = some_value  # WRONG — no @export; class is not a Resource

# Registering as AutoLoad: WRONG — no runtime state, wastes Autoload slot
```

### Usage Pattern (correct)

```gdscript
# Any GDScript file — no import needed
func take_damage(source: GameEnums.DamageSource) -> void:
    if source == GameEnums.DamageSource.DOT:
        _handle_dot_damage()

# .tres resource with enum field (requires explicit int assignments for stability)
class_name PranaType extends Resource
@export var damage_class: GameEnums.DamageClass = GameEnums.DamageClass.FIRE
```

### Stability Constraint for `.tres` Files

All enum constants in GameEnums **must use explicit integer assignments**. `.tres` files serialize `@export` enum properties as integers, not string names. If enum order changes without explicit assignments, previously saved `.tres` files will silently load wrong values with no error.

Example of why this matters:

```gdscript
# BEFORE (DamageClass.ICE = 3 because it's the 4th entry)
enum DamageClass { FIRE, SHADOW, LIGHTNING, ICE, NATURE }

# AFTER (inserting ARCANE at position 2 — now ICE = 4, NATURE = 5)
enum DamageClass { FIRE, SHADOW, ARCANE, LIGHTNING, ICE, NATURE }
# Existing .tres files that stored ICE (3) now load as LIGHTNING (3) — SILENT DATA CORRUPTION

# CORRECT: explicit assignments prevent this
enum DamageClass { FIRE = 0, SHADOW = 1, LIGHTNING = 2, ICE = 3, NATURE = 4 }
# New type appended: ARCANE = 5 — existing .tres files unaffected
```

**Verification gate (before authoring any `.tres` files):** Create a throwaway `TestResource extends Resource` with `@export var damage_class: GameEnums.DamageClass`. Save it. Open the `.tres` in a text editor. If the value appears as `0` (integer): the stability constraint is critical — explicit assignments mandatory. If it appears as `"FIRE"` (string name): explicit assignments are still best practice but not a safety issue. Record the result in the implementation notes.

### Adding New Enums

New enums must be appended to the file — existing values must never be reordered or renumbered. This file has no versioning separate from the project's git history.

## Alternatives Considered

### Alternative B: Define Enums in the Owning System's File

- **Description**: Each enum lives in the system that owns it. `DamageClass` in `prana_catalog.gd`; `DamageSource` in `health_and_damage.gd`.
- **Pros**: Enums co-located with their primary user; no shared-dependency file
- **Cons**: Cross-system consumers must `preload()` the owning system's file to access the enum, creating import chains; `.tres` files that reference `health_and_damage.gd` enum values would fail to load if the script path changes; circular imports become likely once 3+ systems share the same enum
- **Rejection Reason**: Import chains break GUT testability (can't load H&D.gd in isolation); `.tres` path coupling is fragile.

### Alternative C: GameEnums as Autoload

- **Description**: `GameEnums` registered as the first Autoload. Access via `GameEnums.DamageClass.FIRE`.
- **Pros**: No functional difference from `class_name` for this static class
- **Cons**: Wastes one Autoload slot for a class with no runtime state; adds one `_ready()` call at startup for no purpose; access pattern identical to `class_name` — zero benefit
- **Rejection Reason**: Strictly worse than `class_name` with no advantage.

### Alternative D: Constants Dictionary

- **Description**: A single Dictionary Autoload holds all values: `Const.DAMAGE_CLASS_FIRE = 0`.
- **Pros**: Language-agnostic; familiar to non-GDScript developers
- **Cons**: No type safety — Dictionary values are untyped; no editor autocomplete for `Const.DAMAGE_CLASS_*` vs `Const.ENEMY_ARCHETYPE_*`; explicit integer assignments still needed for `.tres` stability
- **Rejection Reason**: GDScript enums provide type-safe access with full editor autocomplete for free; Dictionary provides no advantage.

## Consequences

### Positive

- Every system accesses shared enums via `GameEnums.X.Y` — one canonical location, zero import boilerplate
- Explicit integer assignments make `.tres` files stable across refactors
- `extends RefCounted` prevents accidental scene tree integration
- GUT tests for any system can reference `GameEnums` without loading any gameplay system (no circular deps)

### Negative

- All shared enums are in one file — any new shared enum requires a PR touching `game_enums.gd`
- If the file is accidentally registered as an Autoload, it will work silently but waste an Autoload slot and initialization time

### Risks

- **Risk**: Developer adds a `preload()` inside `game_enums.gd`.
  **Mitigation**: Rule enforced in code review. CI grep for `preload(` or `load(` in `game_enums.gd` on every push.
- **Risk**: Developer reorders enum constants without explicit integer assignments.
  **Mitigation**: Explicit integer assignments on all constants; the `.tres` verification gate must be run before any `.tres` file is authored.
- **Risk**: Enum value needed by a system that isn't listed here is added to a different file.
  **Mitigation**: Code review checklist — "does this introduce a new cross-system enum? If yes, add to `game_enums.gd`."
- **Risk**: `match` statements with exhaustive arms on `BaseStatus` won't produce a warning when CHILL or STAGGER are appended — new values fall through silently.
  **Mitigation**: Add an exhaustive-match check to the code review checklist. Search for `match.*BaseStatus` on every `game_enums.gd` change and verify all arms are handled.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| prana-data.md | `DamageClass`, `DamageSource`, `BaseStatus`, `CastAnimation`, `VfxBurstShape` must be defined in `src/data/game_enums.gd` | This ADR formalizes that decision and adds the stability constraint |
| prana-data.md | Explicit integer assignments required for `.tres` serialization stability | Stability constraint and verification gate documented here |
| prana-data.md | No `extends`, no `preload`, no `load`, no `@onready` in game_enums.gd | Forbidden patterns section of this ADR |
| health-damage.md | `DamageSource.DIRECT`, `DamageSource.DOT`, `DamageSource.CONTACT` used across H&D, SEM, and SC&E | Single definition in GameEnums ensures consistent integer values |
| game-state-scene-flow.md | `GameState` enum used by GameStateManager and consumed by all signal handlers | `GameState` defined here; all consumers use `GameEnums.GameState.COMBAT_PHASE` |
| status-effects.md | `CHILL` and `STAGGER` must exist in `BaseStatus` before any `apply_status()` call using these types compiles | Added as `CHILL = 5, STAGGER = 6`; explicit assignments prevent .tres instability on future appends |

## Performance Implications

- **CPU**: `class_name` lookup is a compile-time constant — zero runtime overhead per access
- **Memory**: One static class parsed once — negligible
- **Load Time**: No `_ready()`, no resource loading — zero startup cost

## Validation Criteria

1. **AC-0006-01**: `game_enums.gd` contains no `preload()`, `load()`, `@onready`, or `extends` beyond `extends RefCounted` — verified by CI grep
2. **AC-0006-02**: `game_enums.gd` is NOT listed in Project Settings → AutoLoad — verified by manual inspection
3. **AC-0006-03**: All enum constants have explicit integer assignments — verified by CI grep for enum blocks without `=`
4. **AC-0006-04**: Throwaway `.tres` verification test completed and result documented before first `.tres` file authored — verified by presence of result note in implementation notes or a separate dev log

## Related Decisions

- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — explicitly excludes GameEnums from Autoload list
- [ADR-0008: PranaCatalog Immutability](adr-0008-prana-catalog-immutability.md) — PranaType `.tres` files use `GameEnums.DamageClass` and `GameEnums.BaseStatus`; stability constraint here ensures those fields serialize correctly
- [docs/architecture/architecture.md](../architecture.md) — Foundation Layer (GameEnums); API Boundaries (DamageClass, DamageSource enum definitions); Cross-Cutting Invariants (explicit integer assignments)
