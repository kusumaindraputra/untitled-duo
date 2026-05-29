# ADR-0003: Signal-Driven Architecture — No Direct Cross-System Polling

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Signals / Event System) |
| **Knowledge Risk** | LOW — GDScript signal system unchanged since Godot 4.0; no breaking changes in 4.4–4.6 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — signal connections use Callable syntax (standard since Godot 4.0) |
| **Verification Required** | None beyond standard testing — signal mechanics are stable in Godot 4.6 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — defines which systems are Autoloads; this ADR defines how they communicate. Registration order from ADR-0002 Rule 3 prevents unsafe Autoload-to-Autoload connections. |
| **Enables** | ADR-0004, ADR-0005, ADR-0006, ADR-0007 — all downstream ADRs rely on knowing the cross-system communication pattern |
| **Blocks** | All coding — no implementation may begin without the communication contract defined |
| **Ordering Note** | Must be Accepted before any cross-system connection code is written |

## Context

### Problem Statement
The project has 10 Autoload singletons and multiple scene-local systems that must interact without creating tight coupling. Without a documented communication contract, developers will write direct state reads across system boundaries (e.g., reading `HealthAndDamage.current_hp` every frame in a display system's `_process()` loop), creating dependencies that break unit testability, hide initialization order requirements, and make systems impossible to test in isolation.

### Constraints
- Godot 4.6 signals do not support return values — operations that require a response must use direct method calls
- Signal handlers are called synchronously in GDScript unless `call_deferred()` is used — the emitting frame is blocked during all handler calls
- `PROCESS_MODE_PAUSABLE` systems will not receive `_process()` calls while the tree is paused, but signal connections remain active — signals emitted during a paused frame still fire handlers if the receiver is `PROCESS_MODE_ALWAYS`

### Requirements
- Display systems (CombatHUD, future UI) must be addable/removable without modifying the systems they display
- Systems must be independently testable in GUT with stub signal emitters replacing real Autoloads
- No system may create a state inconsistency by reading stale cross-system state in a polling loop
- Signal connections between Autoloads must follow the registration order established in ADR-0002

## Decision

Systems communicate via **exactly two patterns**. All other cross-system communication is forbidden.

### Pattern 1 — Signals (for notifications and events)

Use when: a system needs to announce that something happened, and zero or more other systems may care.

The **emitting system** owns the event definition and decides when to emit.
The **consuming system** connects in `_ready()` and reacts without knowing who else listens.

```gdscript
# ── Emitting system (HealthAndDamage) defines and emits the signal ──────────
signal player_hp_zone_changed(zone: GameEnums.HPZone)

func _apply_zone_transition(new_zone: GameEnums.HPZone) -> void:
    _current_zone = new_zone
    player_hp_zone_changed.emit(new_zone)

# ── Consuming system (CombatHUD) connects in _ready() and reacts ────────────
func _ready() -> void:
    HealthAndDamage.player_hp_zone_changed.connect(_on_hp_zone_changed)

func _on_hp_zone_changed(zone: GameEnums.HPZone) -> void:
    if zone == GameEnums.HPZone.DESPERATE:
        _show_danger_overlay()
```

### Pattern 2 — Method Calls (for explicit operations)

Use when: a system needs to instruct another system to perform an operation it owns, and the call is synchronous and intentional.

The **calling system** triggers the operation.
The **receiving system** owns the operation's logic and is the sole executor.

```gdscript
# ── SpellCastingEffects calls apply_damage() — H&D owns damage calculation ──
HealthAndDamage.apply_damage(target, base_damage, element, DamageSource.DIRECT)

# ── PlayerController calls play_event() — AudioSystem owns audio routing ────
AudioSystem.play_event(&"sfx_fayde_footstep")

# ── SpellCastingEffects calls apply_status() — SEM owns effect lifecycle ────
StatusEffectsManager.apply_status(target, BaseStatus.BURN, 3.0)
```

### Forbidden: Direct Cross-System State Reads

Reading state owned by another system — especially in `_process()` — is forbidden.

```gdscript
# ── FORBIDDEN: polling cross-system state every frame ───────────────────────
func _process(delta: float) -> void:
    if HealthAndDamage._current_hp < 20:            # reads private state
        _show_danger_overlay()
    if GameStateManager.get_active_state() == ...:  # polls state machine every frame
        _update_layout()

# ── CORRECT: react to signals once, not every frame ─────────────────────────
func _ready() -> void:
    HealthAndDamage.player_hp_zone_changed.connect(_on_hp_zone_changed)
    GameStateManager.combat_started.connect(_on_combat_started)
    GameStateManager.preparation_started.connect(_on_preparation_started)
```

The only permitted `get_*` calls in `_process()` are on state the calling system itself owns.

### Signal Connection Rules

**Rule 1 — Connect in `_ready()`, never in `_init()`**
Autoloads are not in the scene tree during `_init()`. See ADR-0002 lifecycle rules.

**Rule 2 — Use Callable syntax; never use string-based connections**
```gdscript
# ✓ CORRECT — typed, refactor-safe
some_signal.connect(_handler)
some_signal.connect(_handler, CONNECT_ONE_SHOT)  # or Object.CONNECT_ONE_SHOT — both valid

# ✗ FORBIDDEN — string-based, deprecated since Godot 4.0
connect("some_signal", self, "_handler")
```

**Rule 3 — No circular Autoload subscriptions**
If Autoload A subscribes to a signal from Autoload B, Autoload B must NOT subscribe to any signal from Autoload A. Circular subscriptions create initialization order ambiguity (one connection will silently fail depending on registration order) and make signal chains untraceable.

**Rule 4 — Scene nodes must disconnect from Autoload signals in `_exit_tree()`**
When a scene node is freed (`queue_free()`), Godot 4.6 automatically invalidates orphaned Callable connections, but prints an error to Output on the next emit. Suppress this by explicitly disconnecting in `_exit_tree()`:

```gdscript
func _exit_tree() -> void:
    if HealthAndDamage.player_hp_zone_changed.is_connected(_on_hp_zone_changed):
        HealthAndDamage.player_hp_zone_changed.disconnect(_on_hp_zone_changed)
```

Autoload-to-Autoload connections do not need this treatment — all 10 Autoloads live for the entire session.

**Rule 5 — Signal parameter types are documentation, not runtime enforcement**
GDScript typed signal parameters (`signal foo(param: SomeType)`) are used for editor autocomplete and code clarity. They do not enforce types at runtime. Never assume a signal handler's argument is the correct type without validating at system boundaries.

### Cross-System Interaction Map

| Emitter | Signal | Consumers |
|---------|--------|-----------|
| GameStateManager | `run_started` | HealthAndDamage, RunManager |
| GameStateManager | `preparation_started(wave_index, waves_remaining)` | PlayerController, EnemyInstance, PranaGrid, CombatHUD, AudioSystem |
| GameStateManager | `combat_started(is_boss)` | PlayerController, EnemyInstances, CombatHUD, AudioSystem, WaveManager, CombinationResolution |
| GameStateManager | `grid_locked` | PranaGrid |
| GameStateManager | `grid_hidden` | PranaGrid |
| GameStateManager | `wave_ended` | RunManager |
| GameStateManager | `death_started` | AudioSystem |
| GameStateManager | `run_ended(win)` | RunManager |
| HealthAndDamage | `damage_taken(target, final_damage, current_hp)` | CombatHUD |
| HealthAndDamage | `health_restored(target, healed_amount, current_hp)` | CombatHUD |
| HealthAndDamage | `player_died` | GameStateManager |
| HealthAndDamage | `enemy_killed(instance_id, type_id, prana_affiliation)` | WaveManager, StatusEffectsManager |
| HealthAndDamage | `heavy_hit(target, final_damage)` | CombatHUD, AudioSystem |
| HealthAndDamage | `player_hp_zone_changed(zone)` | CombatHUD, AudioSystem |
| PranaGrid | `arrangement_confirmed` | GameStateManager |
| CombinationResolution | `combo_resolved(spell_effect)` | SpellCastingEffects |
| SpellCastingEffects | `chain_index_changed(combo_index, combo_attack_count)` | CombatHUD |
| SpellCastingEffects | `spell_hit_element(target, prana_type_id)` | CombatHUD |
| SpellCastingEffects | `cast_hit_started(lock_duration)` | PlayerController |
| WaveManager | `wave_cleared` | GameStateManager |
| WaveManager | `all_waves_cleared` | GameStateManager |
| WaveManager | `boss_defeated` | GameStateManager (via call_deferred) |

## Alternatives Considered

### Alternative B: Full Signal-Only (No Direct Method Calls)
- **Description**: Every inter-system interaction goes through signals, including operations like `apply_damage()`. The calling system emits a signal; the owning system catches it and executes.
- **Pros**: Perfect decoupling — emitters and receivers have zero knowledge of each other
- **Cons**: Godot signals are void-return only. Operations like `apply_damage()` have no immediate feedback path. Workarounds (callback signals) add complexity with no practical benefit. Debugging signal chains for operations is much harder than a direct call stack.
- **Rejection Reason**: Impractical in Godot 4.6. Direct method calls for explicit operations are idiomatic and correct when the operation has a single owner.

### Alternative C: Polling (Direct State Reads in _process())
- **Description**: Systems read other systems' state properties in `_process(delta)` to detect changes and react.
- **Pros**: Simple to write; no signal boilerplate
- **Cons**: Coupling to implementation details; stale-by-one-frame reads; no way to test the display system without a live game system running; `_process()` runs every frame even when state hasn't changed (wasted CPU); breaks if the owning system's internal representation changes
- **Rejection Reason**: Explicitly violates Architecture Principle 2 ("State lives in one owner"). Forbidden by this ADR.

### Alternative D: Event Bus Autoload
- **Description**: A single `EventBus` Autoload broadcasts named events as `Dictionary` payloads. Systems subscribe by event name string (e.g., `EventBus.subscribe("player_died", _handler)`).
- **Pros**: Ultimate decoupling — no system knows any other system exists
- **Cons**: Loses GDScript type safety entirely; string-keyed event names are not refactor-safe; debugging requires tracing string names through a bus rather than following Godot's native signal graph; Godot already provides a native event bus (signals + class_name access) that is type-safe
- **Rejection Reason**: Adds complexity to replicate functionality Godot provides natively with worse type safety.

## Consequences

### Positive
- Display and audio systems (CombatHUD, AudioSystem) can be added, removed, or replaced without modifying any gameplay system they observe
- Every system is independently unit-testable: stub the signal emitters in GUT to replace real Autoloads
- Debugger's "Signals" panel shows all connections — signal architecture is visible and inspectable
- No frame-lag: signal handlers run in the same frame as the emit (synchronous by default)

### Negative
- Signal handler order within a single signal emit is not guaranteed for multiple consumers; handlers must be order-independent
- A system that misses a signal (connects after the emit) sees no history — initial state must be read via a method call on first connect, not from a prior signal
- `_exit_tree()` cleanup boilerplate is required on every scene node that connects to an Autoload signal

### Risks
- **Risk**: Developer adds a new display system and reads Autoload state in `_process()` instead of connecting to a signal.
  **Mitigation**: Code review checklist item — "does this system read properties of another system in `_process()`?". Explicit ban documented here.
- **Risk**: A scene node is freed, leaving an orphaned signal connection that prints errors on next emit.
  **Mitigation**: Rule 4 above (`_exit_tree()` disconnect pattern). Error is non-crashing but noisy — treat any "Method not found" signal error as a bug.
- **Risk**: Developer creates circular Autoload signal subscriptions.
  **Mitigation**: Rule 3 above. ADR-0002 registration order already prevents the worst cases; this rule closes the remainder.

## GDD Requirements Addressed

| GDD System | Requirement (TR ID) | How This ADR Addresses It |
|------------|---------------------|--------------------------|
| game-state-scene-flow.md | TR-GSF-002: GameStateManager is the sole emitter of game state transition events; no other system may transition state directly | Signal-only pattern: no system calls `_request_transition()` directly; all state changes flow through GSM's public signal emissions |
| prana-grid.md | TR-PG-004: PranaGrid notifies upstream systems about user input via `arrangement_confirmed` signal, not by calling GSM methods | Signal pattern (Pattern 1) — PranaGrid emits; GSM connects and reacts. PranaGrid has no reference to GSM. |
| combat-hud.md | TR-CH-002: CombatHUD is a passive listener; it never reads game state directly and never calls methods on gameplay systems | CombatHUD implements Pattern 1 only (signal consumer). All HP, combo, and state information arrives via signals. |
| run-management.md | TR-RM-004: RunManager accumulates wave count and run outcome from GSM signals; never polls `get_active_state()` in `_process()` | Signal pattern (Pattern 1) — RunManager connects to `run_started`, `wave_ended`, `run_ended` in `_ready()`; no `_process()` loop reads GSM |

## Performance Implications
- **CPU**: Signal emission in GDScript has a negligible per-call overhead (~microseconds). The number of signals in this project (~20 signal types, each firing a few times per second at most) produces no measurable frame budget impact.
- **Memory**: Signal connections are stored as a small metadata list per signal per object. 20 signals × avg 3 consumers = ~60 Callable objects total. Negligible.
- **Load Time**: All connections established in `_ready()` — no deferred connection setup. No load time impact.
- **Network**: N/A

## Migration Plan
New project — no existing code to migrate. First enforced at the first story that implements any cross-system interaction.

## Validation Criteria
1. **AC-0003-01**: No system's `_process()` or `_physics_process()` contains direct reads of properties on another system's Autoload (verified by code review + CI grep for `AutoloadName.property` patterns inside `_process` bodies)
2. **AC-0003-02**: All signal connections use Callable syntax — no string-based `connect("signal_name", self, "method")` calls exist in any gameplay file
3. **AC-0003-03**: Scene nodes that connect to Autoload signals implement `_exit_tree()` with explicit `disconnect()` calls
4. **AC-0003-04**: No circular Autoload-to-Autoload signal subscriptions exist in any Autoload's `_ready()` method

## Related Decisions
- [ADR-0002: Autoload Architecture and Registration Order](adr-0002-autoload-architecture.md) — defines which systems are Autoloads; Rule 3 (no higher-autoload method calls in `_ready()`) prevents unsafe signal connections
- [ADR-0007: HealthAndDamage as Autoload Singleton](adr-0007-health-damage-singleton.md) — specifies the full signal contract for the damage/health event system
- [docs/architecture/architecture.md](../architecture.md) — Cross-Cutting Invariants table; Architecture Principles 1 & 2
