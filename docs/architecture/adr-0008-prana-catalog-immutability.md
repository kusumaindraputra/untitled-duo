# ADR-0008: PranaCatalog Immutability via duplicate_deep()

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Resource management, Autoload) |
| **Knowledge Risk** | MEDIUM — `duplicate_deep()` introduced in Godot 4.5 (post-cutoff); `duplicate(true)` deprecated |
| **References Consulted** | `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/breaking-changes.md`, `prana-data.md` (Implementation Notes, Core Rule 1) |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` — introduced Godot 4.5; replaces deprecated `duplicate(true)` |
| **Verification Required** | Verify `duplicate_deep()` isolates property reassignment on `PranaType` in Godot 4.6: call `get_type(0)`, mutate `base_damage_modifier`, call `get_type(0)` again, confirm original value unchanged. Also verify `AudioStream` and `Texture2D` fields share underlying data by reference (expected — correct behavior). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — PranaCatalog is Autoload #1; this ADR specifies its implementation contract |
| **Enables** | PranaGrid, CombinationResolution, SpellCastingEffects — all call `get_type()` freely, trusting immutability |
| **Blocks** | PranaCatalog implementation; any system that calls `PranaCatalog.get_type()` |
| **Ordering Note** | Must be Accepted before PranaCatalog.gd is written |

## Context

### Problem Statement

Five systems read Prana type definitions from PranaCatalog at runtime: PranaGrid (slot rendering), CombinationResolution (combo lookup), SpellCastingEffects (VFX/audio routing), Elemental Affiliation (weakness multiplier), and test suites. If any consumer modifies a returned `PranaType` instance — intentionally (testing) or accidentally (stale reference) — it must not corrupt the catalog for all other readers. Without immutability enforcement, a test that modifies `base_damage_modifier` for isolation purposes permanently changes the type for every subsequent call in that session.

Additionally, PranaCatalog is Autoload #1 — any other Autoload that calls `get_type()` during its `_ready()` would succeed (PranaCatalog is guaranteed first). But the initialization guard (`_initialized` flag) must use `push_error()`, not `assert()`, because `assert()` is stripped from Godot 4.6 release builds.

### Constraints

- Godot 4.6: `duplicate()` with a `bool` argument is deprecated since 4.5 — use `duplicate_deep()`
- `duplicate_deep()` copies property values into a new wrapper object; file-backed assets (`AudioStream`, `Texture2D`) share underlying data by reference (not deep-copied) — this is the correct behavior
- PranaCatalog must be the first Autoload in Project Settings (ADR-0002)
- Unit tests must be able to mutate returned instances for isolation without affecting other tests

### Requirements

- `get_type()` must return an instance whose property mutations are invisible to other callers
- `push_error()` used for all guards (not `assert()`) — survives release exports
- Startup validation must catch null assets, zero modifiers, wrong ID assignments
- EnemyCatalog follows an identical pattern (for `EnemyType` resources)

## Decision

`PranaCatalog.get_type(id: int) -> PranaType` always returns `original.duplicate_deep()`. The method never returns a direct reference to the stored catalog entry.

### Implementation

```gdscript
class_name PranaCatalog
extends Node

var _initialized: bool = false
var _types: Array[PranaType] = []  # indexed by id

func _ready() -> void:
    _load_types()
    _validate_all()
    _initialized = true

func get_type(id: int) -> PranaType:
    if not _initialized:
        push_error("PranaCatalog.get_type() called before _ready() — check Autoload order")
        return null
    if id < 0 or id >= _types.size():
        push_error("PranaCatalog.get_type(): invalid ID %d (catalog has %d types)" % [id, _types.size()])
        return null
    return _types[id].duplicate_deep()  # ← isolation guarantee

func get_all_types() -> Array[PranaType]:
    var result: Array[PranaType] = []
    for t in _types:
        result.append(t.duplicate_deep())
    return result
```

### Why `duplicate_deep()`, Not `duplicate()`

```gdscript
# Godot 4.5+: duplicate_deep() is the explicit API for nested resource deep copy
var copy: PranaType = original.duplicate_deep()

# DEPRECATED since 4.5 — do NOT use:
var copy: PranaType = original.duplicate(true)  # bool arg form deprecated
```

`duplicate_deep()` creates a new `PranaType` object with independent property values. Mutating `copy.base_damage_modifier` does not affect `original.base_damage_modifier`.

**File-backed assets are correctly shared:** `copy.audio_signature` and `copy.icon` point to the same underlying `AudioStream`/`Texture2D` data. This is intentional — `duplicate_deep()` does not copy pixel or audio data; it only copies object property slots. If a consumer reassigns `copy.audio_signature = some_other_stream`, that reassignment affects only `copy`, not `original`. This is the correct immutability model.

### Startup Validation

```gdscript
func _validate_all() -> void:
    for expected_id in range(_types.size()):
        var t: PranaType = _types[expected_id]
        if t == null:
            push_error("PranaCatalog: type at index %d is null" % expected_id)
            continue
        if t.id != expected_id:
            push_error("PranaCatalog: type at index %d has wrong id %d" % [expected_id, t.id])
        if t.base_damage_modifier <= 0.0:
            push_error("PranaCatalog: type %d has base_damage_modifier <= 0" % t.id)
        if t.name.is_empty():
            push_error("PranaCatalog: type %d has empty name" % t.id)
        if t.audio_signature == null:
            push_error("PranaCatalog: type %d has null audio_signature" % t.id)
        if t.icon == null:
            push_error("PranaCatalog: type %d has null icon" % t.id)
```

These validations use `push_error()` — they write to the engine error log in debug AND release builds and do not crash the game. A null `AudioStream` produces a silent cast; a null `Texture2D` produces a blank grid slot; `base_damage_modifier = 0.0` produces zero-damage spells. All are development-time failures that must surface immediately, not fail silently.

### EnemyCatalog Parallel Pattern

`EnemyCatalog` follows the same contract for `EnemyType` resources:

```gdscript
class_name EnemyCatalog
extends Node

func get_type(id: int) -> EnemyType:
    # ... same _initialized guard, id bounds check ...
    return _types[id].duplicate_deep()

func get_active_types() -> Array[EnemyType]:
    return _types.filter(func(t): return t.is_active).map(func(t): return t.duplicate_deep())
```

### `_initialized` Guard: `push_error()` Not `assert()`

```gdscript
# ── CORRECT ───────────────────────────────────────────────────────────────────
if not _initialized:
    push_error("PranaCatalog.get_type() called before _ready()")
    return null

# ── WRONG — assert() stripped from release builds ────────────────────────────
assert(_initialized, "PranaCatalog not ready")  # WRONG: silent failure in release
```

Godot 4.6 release export strips `assert()` statements. A consumer that calls `get_type()` before `_ready()` would receive an unguarded null return in release builds — leading to a crash or silent bad data with no log entry. `push_error()` writes to the engine log in all build types.

## Alternatives Considered

### Alternative B: Return Direct Reference (No Immutability)

- **Description**: `get_type(id)` returns the stored `_types[id]` directly.
- **Pros**: Zero copy overhead per call
- **Cons**: Any consumer mutation corrupts the catalog for all subsequent callers in the session; test suite cannot safely mutate types for isolation without resetting the entire catalog
- **Rejection Reason**: Silent corruption bug that doesn't surface until a second system reads the mutated value. Debugging is extremely difficult. The performance cost of `duplicate_deep()` on a 5-entry catalog is unmeasurable.

### Alternative C: Const Properties on PranaType

- **Description**: All PranaType properties declared `const` — GDScript disallows mutation at parse time.
- **Pros**: Compile-time enforcement; zero runtime cost
- **Cons**: `const` properties cannot be `@export` — catalog cannot be authored in the Godot Inspector or stored in `.tres` files; data-driven workflow (core requirement from coding standards) is impossible
- **Rejection Reason**: Incompatible with data-driven workflow. `@export var` is mandatory for inspector-editable, `.tres`-serializable properties.

### Alternative D: Freeze via `lock()`

- **Description**: Call `resource_local_to_scene = false` and then mark the resource as read-only via engine flags.
- **Pros**: Engine-enforced immutability without copying
- **Cons**: Godot 4.6 has no `Resource.lock()` API — this would require a custom frozen flag that callers must check before mutation, which defeats the purpose (callers could skip the check)
- **Rejection Reason**: No such API exists in Godot 4.6.

## Consequences

### Positive

- Consumer code can freely mutate returned `PranaType` instances for local use without side effects
- GUT tests can safely change `prana_type.base_damage_modifier` for a specific test without resetting the catalog
- Startup validation catches corrupt `.tres` files immediately on launch — no silent bad-data runs
- `push_error()` guard is release-safe — startup errors surface in both debug and shipped builds

### Negative

- `duplicate_deep()` allocates a new `PranaType` object on every `get_type()` call — negligible for 5 types called a handful of times per wave, but callers should cache the result rather than calling `get_type()` in `_process()`
- File-backed asset fields (`audio_signature`, `icon`) share underlying data — consumers that replace these fields on the copy will observe the substitution only on their own copy (correct behavior, but may surprise a developer unfamiliar with the contract)

### Risks

- **Risk**: Developer calls `get_type()` in `_process()` without caching, causing per-frame allocations.
  **Mitigation**: Code review checklist item. Canonical pattern: call `get_type()` in `_ready()` and store the result in a local `@onready var`.
- **Risk**: `duplicate()` (deprecated form) used instead of `duplicate_deep()`.
  **Mitigation**: CI grep for `\.duplicate(true)` in PranaCatalog file — deprecated form should never appear.
- **Risk**: `assert()` used instead of `push_error()` in the initialization guard.
  **Mitigation**: Code review. CI grep for `assert(_initialized` in PranaCatalog file.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| prana-data.md | Core Rule 1: All Prana type definitions are immutable at runtime | `get_type()` returns `duplicate_deep()` — consumer mutations don't reach catalog |
| prana-data.md | `duplicate()` with bool arg deprecated since 4.5 — use `duplicate_deep()` | This ADR formalizes `duplicate_deep()` as the required API |
| prana-data.md | `push_error()` not `assert()` for the `_initialized` guard | This ADR mandates `push_error()` and explains the release-build rationale |
| prana-data.md | Startup validation: id, base_damage_modifier, name, audio_signature, icon | Validation code specified exactly in `_validate_all()` above |
| prana-data.md | AC-PD-04b: Caller A mutation invisible to Caller B | `duplicate_deep()` provides this guarantee; test case validates it |
| prana-data.md | AC-PD-04c: Reference-type property reassignment isolated per copy | `duplicate_deep()` isolates `icon` field reassignment; shared underlying data confirmed |

## Performance Implications

- **CPU**: `duplicate_deep()` on a 12-property `Resource` — negligible (< 1μs per call)
- **Memory**: One new `PranaType` object per `get_type()` call — 5 types × calls per frame = effectively zero for a non-process-loop pattern. Total catalog: 5 `PranaType` objects × ~200 bytes = ~1 KB
- **Load Time**: `_load_types()` loads 5 `.tres` files synchronously — < 1ms total; no async loading needed

## Validation Criteria

1. **AC-0008-01**: `get_type(0)` → mutate `base_damage_modifier = 999.0` → `get_type(0)` again → `base_damage_modifier == 1.25` (original unchanged)
2. **AC-0008-02**: `get_type(0)` → replace `icon` with stub texture → `get_type(0)` again → `icon` is original catalog icon (not stub)
3. **AC-0008-03**: Call `get_type(-1)` and `get_type(5)` — both return null and log `push_error()` messages; no crash
4. **AC-0008-04**: Corrupt a `PranaType.tres` (set `base_damage_modifier = 0.0`) → launch game → `push_error()` fires at startup with type ID; catalog still loads remaining valid types
5. **AC-0008-05**: Call `get_type(0)` before `PranaCatalog._ready()` completes (simulated in GUT via `_initialized = false`) → returns null + `push_error()` fires; no crash

## Related Decisions

- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — PranaCatalog is Autoload #1; first because everything depends on it
- [ADR-0006: GameEnums](adr-0006-game-enums-pure-container.md) — `PranaType.damage_class` uses `GameEnums.DamageClass`; explicit integer assignments ensure `.tres` stability
- [docs/architecture/architecture.md](../architecture.md) — Foundation Layer (PranaCatalog module ownership); Architecture Principle 5 (push_error not assert)
