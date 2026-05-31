# ADR-0010: Player and Enemy Group Convention

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (SceneTree Groups / Node Discovery) |
| **Knowledge Risk** | LOW — `add_to_group()`, `is_in_group()`, `get_nodes_in_group()`, `get_first_node_in_group()` APIs unchanged since Godot 3.x; no breaking changes in 4.4–4.6. StringName literals (`&"name"`) available since Godot 4.0. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `get_first_node_in_group(&"player")` returns the PlayerController node in a runtime scene before EnemyAI implementation sprint begins |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — establishes PlayerController and EnemyInstance as scene nodes (not Autoloads); group membership is set in scene-node `_ready()`. ADR-0007 (Accepted) — H&D uses `is_in_group()` for target discrimination in `apply_damage()` and damage signal handlers. |
| **Enables** | None directly — formalizes the existing pattern already used by 3+ GDDs |
| **Blocks** | EnemyAI and H&D implementation stories — these cannot be created without the group name constants documented |
| **Ordering Note** | Should be Accepted before any EnemyAI or H&D implementation stories are created, as those stories embed group name StringName literals |

## Context

### Problem Statement
Three GDDs — Enemy AI (Core Rules 4 and 7), Player Controller (Interface Constraints), and Health & Damage (target discrimination) — each independently reference a `"player"` and `"enemy"` Godot SceneTree group convention for node discovery and signal target filtering. No ADR documents the authoritative rules: which node types join which group, which API to use for lookup, the single-player constraint, and the prohibition against dual-group membership. Without this decision recorded, any rename of the group strings, addition of a second player-type node, or alternative lookup approach introduced in a new system will silently break all consumers.

### Constraints
- Single-player game: exactly one PlayerController (Fayde) node in the scene tree during any combat frame
- EnemyInstance nodes range from 0 (between waves) to ~15 (dense Cluster wave) simultaneously
- No navmesh at FP scope — group lookup is the primary way EnemyAI finds Fayde
- Enemy AI caches the player node reference at `_ready()`; group query runs at most once per EnemyInstance per null-dereference event, not per-frame in normal operation
- `queue_free()` defers deletion to end-of-frame — a node remains in its group until that point

### Requirements
- Must provide a single authoritative string for the player group name used by all consumers
- Must provide a single authoritative string for the enemy group name used by all consumers
- Must define the exact Godot API for player node lookup
- Must prohibit dual membership (a node cannot be in both groups)
- Must work within `PROCESS_MODE_PAUSABLE` (group membership persists across pause/resume)

## Decision

Use Godot's SceneTree group system as the single mechanism for node discovery and target discrimination. Establish two named groups:

1. **`"player"` group** — exactly one member during any active scene: the PlayerController node. PlayerController is responsible for registering itself in `_ready()`.
2. **`"enemy"` group** — zero to N members (active EnemyInstance nodes). Each EnemyInstance is responsible for registering itself in `_ready()`.

Group names are referenced everywhere as GDScript StringName literals (`&"player"`, `&"enemy"`) to avoid runtime string allocation and to enable grep-based inventory of all consumers.

### Architecture Diagram

```
SceneTree
└── [root]
    └── IsometricRoom                ← arena scene root
        ├── PlayerController         ← groups: ["player"]   (exactly 1 during combat)
        ├── EnemyInstance_Drifter    ← groups: ["enemy"]   ─┐
        ├── EnemyInstance_Charger    ← groups: ["enemy"]    ├─ 0..N during combat
        └── EnemyInstance_Cluster    ← groups: ["enemy"]   ─┘

Group Query Flow:
  EnemyAI._ready()       → get_tree().get_first_node_in_group(&"player") → cache _fayde_ref
  H&D signal handler     → target.is_in_group(&"player") → Fayde-specific damage rules
  H&D signal handler     → target.is_in_group(&"enemy")  → enemy HP tracking
  SC&E collision handler → body.is_in_group(&"enemy")    → spell damage target
  EnemyAI body_entered   → body.is_in_group(&"player")   → contact damage gating
```

### Key Interfaces

```gdscript
# ── REGISTRATION (each node in _ready()) ─────────────────────────────────────
# PlayerController:
func _ready() -> void:
    add_to_group(&"player")      # REQUIRED — StringName literal

# EnemyInstance:
func _ready() -> void:
    add_to_group(&"enemy")       # REQUIRED — StringName literal

# ── SINGLE-PLAYER ASSERTION (PlayerController._ready()) ──────────────────────
assert(get_tree().get_nodes_in_group(&"player").size() == 0,
    "Duplicate 'player' group member: only one PlayerController may exist")

# ── LOOKUP: locate Fayde (Enemy AI — cache at _ready(), re-resolve on null) ──
_fayde_ref = get_tree().get_first_node_in_group(&"player")   # null if Fayde not in scene

# ── DISCRIMINATION: in signal handlers and Area2D callbacks ───────────────────
if target.is_in_group(&"player"):    # Fayde-specific path
    pass
if body.is_in_group(&"enemy"):       # enemy-specific path
    pass

# ── AoE QUERY (SC&E spell collision, future splash damage) ────────────────────
# NOTE: get_nodes_in_group() returns untyped Array — do NOT declare as Array[Node]
var enemies: Array = get_tree().get_nodes_in_group(&"enemy")
for enemy: Node in enemies:
    if not is_instance_valid(enemy):    # guard: node may have called queue_free()
        continue
    # process enemy
```

**Invariants enforced by this ADR:**
1. Only `PlayerController` may call `add_to_group(&"player")`. No other node type is permitted.
2. Only `EnemyInstance` scripts may call `add_to_group(&"enemy")`. No other node type is permitted.
3. No node may be a member of both groups simultaneously.
4. Group registration occurs in `_ready()` only — not in `_init()`, not deferred.
5. All consumers of `get_nodes_in_group()` results **must** guard with `is_instance_valid(node)` before calling any method on retrieved nodes. `queue_free()` defers deletion to end-of-frame; a node remains in its group until then and is logically dead but still addressable.

## Alternatives Considered

### Alternative B: Direct Reference Injection
- **Description**: WaveManager injects a reference to PlayerController into each EnemyInstance at spawn via `init(enemy_type_id, player_ref: PlayerController)`. No SceneTree queries.
- **Pros**: Zero SceneTree query overhead; explicit dependency — coupling is visible in the function signature
- **Cons**: WaveManager becomes a coupling point between EnemyAI and PlayerController; any future Fayde lifecycle change (respawn) must be threaded through WaveManager. Does not address H&D and SC&E's need for `is_in_group()` discrimination — the group pattern is still needed for those systems regardless.
- **Rejection Reason**: Doesn't eliminate the group pattern for H&D/SC&E; adds an unnecessary coupling chain through WaveManager for EnemyAI alone.

### Alternative C: Autoload-Mediated Lookup
- **Description**: An existing Autoload (e.g., `GameStateManager`) provides `register_player(node)` / `get_player_node() → PlayerController` methods.
- **Pros**: Centralized registry; explicit ownership; testable via Autoload mock
- **Cons**: GameStateManager grows outside its defined scope (state machine → also node registry); ADR-0002 positions GSM as a state machine, not a node locator. Still doesn't address `is_in_group()` discrimination for H&D/SC&E without a parallel enemy-node registry.
- **Rejection Reason**: Overengineered for a single-player game with a deterministic player node. SceneTree groups are purpose-built for this; no custom infrastructure needed.

## Consequences

### Positive
- `get_first_node_in_group()` short-circuits on the first match — O(1) effectively for a 1-member group; no array allocation
- StringName literals are interned at compile time — zero runtime allocation cost per `is_in_group()` check
- Pattern is already consistent with 3+ GDDs; no design refactor required
- Grep-searchable: `grep -r '"player"' src/` finds all consumers instantly

### Negative
- Group names are string constants, not typed references — a typo (`&"plyer"`) is not caught at compile time; only caught at runtime by silent membership miss
- No compile-time enforcement that PlayerController adds itself to `"player"` in `_ready()` — requires code review discipline
- `get_nodes_in_group()` returns an untyped `Array` — callers cannot declare `Array[Node]` without an explicit typed cast; the untyped form must be used

### Risks
- **Risk**: Developer adds a second player-type node (summoned ally, mirror copy) to the `"player"` group. `get_first_node_in_group()` returns the wrong node non-deterministically.
  **Mitigation**: Invariant #1 bans this explicitly. The single-player assertion in PlayerController's `_ready()` detects duplicates at runtime.
- **Risk**: Enemy AI caches `_fayde_ref`, but Fayde's node is freed and re-instantiated (future respawn mechanic). Stale reference causes null-access crash.
  **Mitigation**: Enemy AI re-resolves via `get_first_node_in_group(&"player")` when `_fayde_ref == null` (Enemy AI Core Rule 4). At FP/MVP scope, Fayde is not destroyed mid-combat.
- **Risk**: Group query on `"enemy"` returns a node between its `queue_free()` call and end-of-frame deletion. Calling a method on it crashes.
  **Mitigation**: Invariant #5 requires `is_instance_valid()` guard on all group-query consumers. H&D Rule 5 already requires this guard independently.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| enemy-ai.md | Core Rule 4: `get_tree().get_first_node_in_group(&"player")` to locate Fayde | Establishes `"player"` group as the authoritative lookup mechanism; confirms the API name |
| enemy-ai.md | Core Rule 7: Enemy instances must be in `"enemy"` group; must NOT be in `"player"` group | Establishes `"enemy"` group membership as a requirement on EnemyInstance `_ready()`; prohibits dual membership |
| enemy-ai.md | Contact attack: `body.is_in_group("player")` for contact damage gating | Confirms `is_in_group(&"player")` as the approved discrimination API |
| player-controller.md | Interface Constraints: "Player Controller must maintain 'player' group membership; Enemy AI accesses position via the cached node reference" | Makes this constraint authoritative; adds the single-player assertion as the enforcement mechanism |
| health-damage.md | Target discrimination: `is_in_group("player")` distinguishes Fayde from enemies in signal handlers | Confirms `is_in_group()` as the approved discrimination pattern for H&D signal callbacks |
| spell-casting-effects.md | Spell collision: must identify enemy targets vs. player | `is_in_group(&"enemy")` on collision body is the approved target check |

## Performance Implications
- **CPU**: `get_first_node_in_group()` — O(1) for a 1-member group; short-circuits on first match; no array allocation. `is_in_group()` — O(1) hash lookup per call. Negligible at this project's scale.
- **Memory**: Two hash-table entries in SceneTree's internal group map. Unmeasurable.
- **Load Time**: None — group membership is added in `_ready()`, not at project load.
- **Network**: N/A

## Migration Plan
New project — no existing code to migrate. All GDDs already specify the correct group names. Developer action: implement `add_to_group(&"player")` in PlayerController's `_ready()` and `add_to_group(&"enemy")` in EnemyInstance's `_ready()` as specified.

## Validation Criteria
1. **AC-0010-01** — GIVEN a PlayerController instance after `_ready()`, WHEN `is_in_group("player")` is called, THEN returns `true`.
2. **AC-0010-02** — GIVEN a PlayerController instance after `_ready()`, WHEN `is_in_group("enemy")` is called, THEN returns `false` (dual membership prohibited).
3. **AC-0010-03** — GIVEN an EnemyInstance after `_ready()`, WHEN `is_in_group("enemy")` is called, THEN returns `true`.
4. **AC-0010-04** — GIVEN an EnemyInstance after `_ready()`, WHEN `is_in_group("player")` is called, THEN returns `false` (dual membership prohibited).
5. **AC-0010-05** — GIVEN a scene with one PlayerController and one EnemyInstance, WHEN `get_tree().get_first_node_in_group(&"player")` is called from any node, THEN the returned object is the PlayerController instance (not null, not the EnemyInstance).

## Related Decisions
- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — defines PlayerController and EnemyInstance as scene nodes; group membership established in scene-node `_ready()`
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — signal handlers use `is_in_group()` as the approved discrimination pattern
- [ADR-0007: Health and Damage Autoload Singleton](adr-0007-health-damage-autoload-singleton.md) — target discrimination in `apply_damage()` uses `is_in_group()` per this ADR
