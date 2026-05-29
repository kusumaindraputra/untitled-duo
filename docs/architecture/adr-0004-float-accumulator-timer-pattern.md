# ADR-0004: Float Accumulator Timer Pattern

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (Timing / Process) |
| **Knowledge Risk** | LOW — `_process(delta)` and `PROCESS_MODE_PAUSABLE` unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `PROCESS_MODE_PAUSABLE` correctly halts `_process()` on `get_tree().paused = true` in a minimal test scene |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — establishes which systems are Autoloads; all Autoloads with timing follow this pattern |
| **Enables** | All Core-layer implementation sprints — StatusEffectsManager, SpellCastingEffects, PlayerController, EnemyInstance |
| **Blocks** | Any story that implements a game timer |
| **Ordering Note** | Must be Accepted before the first implementation story that involves any time-based gameplay behavior |

## Context

### Problem Statement

The game has many timer-based behaviors: status effect durations (Burn 2s, Freeze 2s, Regen 3s), status tick intervals (0.5s Burn, 1.0s Regen), the SpellCastingEffects CAST_LOCKED window, the Lightning Follow-Through 1.5s window, PlayerController dash cooldown, EnemyInstance contact interval (0.3s), and footstep audio. Without a documented timer pattern, different developers will reach for different solutions — `Timer` nodes, `SceneTree.create_timer()`, or `_process(delta)` accumulators — producing inconsistent pause behavior.

### Constraints

- All gameplay timers must pause when `get_tree().paused = true` (Pause Menu)
- Godot 4.6: `PROCESS_MODE_PAUSABLE` is the only process mode that automatically halts `_process()` on tree pause
- `SceneTree.create_timer()` creates a timer that runs on the process frame, not physics — and its behavior under `PROCESS_MODE_ALWAYS` or `PROCESS_MODE_PAUSABLE` is determined by the optional `process_always` and `process_in_physics` arguments (easy to get wrong)
- Timer nodes (`Timer`) follow the PROCESS_MODE of their parent node — but if a Timer node lives in an Autoload with `PROCESS_MODE_ALWAYS`, it will tick even while paused
- Solo developer context: consistent pattern enforced by convention, not tooling

### Requirements

- All timer systems pause correctly when `get_tree().paused = true`
- Timer values survive PROCESS_MODE transitions without special-casing
- Timers are independently testable with GUT without a running SceneTree timer
- Pattern must handle both "count up to threshold" (tick interval) and "count down from duration" (status expiry) use cases

## Decision

**All in-game timing uses float delta accumulators in `_process(delta)`.** `Timer` nodes and `SceneTree.create_timer()` are forbidden for gameplay timing.

The pattern:

```gdscript
# ── Count-up pattern: fire when accumulator reaches threshold ──────────────────
var _burn_timer: float = 0.0

func _process(delta: float) -> void:
    _burn_timer += delta
    if _burn_timer >= burn_tick_rate:
        _burn_timer -= burn_tick_rate  # decrement, not reset — preserves sub-frame precision
        _fire_burn_tick()

# ── Count-down pattern: expire when accumulator reaches 0 ─────────────────────
var _freeze_timer: float = 0.0

func apply_freeze(duration: float) -> void:
    _freeze_timer = duration  # set on application

func _process(delta: float) -> void:
    if _freeze_timer > 0.0:
        _freeze_timer -= delta
        if _freeze_timer <= 0.0:
            _freeze_timer = 0.0
            _on_freeze_expired()

# ── Pause behavior: set all Gameplay Autoloads to PROCESS_MODE_PAUSABLE ────────
# StatusEffectsManager, SpellCastingEffects, CombinationResolution, EnemyInstance
# → these all halt when get_tree().paused = true, without any special pause logic.
#
# ── Exceptions: PROCESS_MODE_ALWAYS ───────────────────────────────────────────
# CombatHUD — must continue rendering even when paused (show pause overlay)
# AudioSystem — must respond to pause/resume signals (duck music, play SFX)
```

### Why Decrement, Not Reset

`_burn_timer -= burn_tick_rate` instead of `_burn_timer = 0.0` preserves sub-frame precision. At 60fps, `delta` ≈ 0.0167s. If `burn_tick_rate = 0.5s`, the accumulator will slightly overshoot on the tick frame (e.g., 0.5083s). Decrementing subtracts exactly 0.5s, carrying the 0.0083s overshoot into the next interval. Resetting to 0.0 discards it, causing cumulative drift over 4 ticks that can be visually perceptible (tick 4 arrives ~0.033s late).

### Forbidden Alternatives

```gdscript
# ── FORBIDDEN: Timer node inside an Autoload (doesn't auto-pause) ─────────────
@onready var _burn_timer: Timer = $BurnTimer  # WRONG — Autoloads have no scene path

# ── FORBIDDEN: SceneTree.create_timer() ────────────────────────────────────────
await get_tree().create_timer(burn_tick_rate).timeout  # WRONG — pausing behavior depends
                                                       # on process_always arg; coroutine
                                                       # lifecycle is hard to test in GUT

# ── FORBIDDEN: OS.get_ticks_msec() delta calculation ──────────────────────────
var _last_tick: int = OS.get_ticks_msec()  # WRONG — wall-clock time, ignores game pause;
                                            # also: deprecated since Godot 4.0 — use Time.get_ticks_msec()
```

### Process Mode Assignments (from architecture.md)

| Module | Process Mode | Reason |
|--------|-------------|--------|
| StatusEffectsManager | PAUSABLE | All status timers halt on pause |
| SpellCastingEffects | PAUSABLE | Cast timing halts on pause |
| PlayerController | PAUSABLE | Player input halts on pause |
| EnemyInstance | PAUSABLE | Enemy behavior halts on pause |
| CombatHUD | ALWAYS | Must render pause overlay |
| AudioSystem | ALWAYS | Must play pause SFX and duck music |
| GameStateManager | ALWAYS | Must respond to pause/resume input |

## Alternatives Considered

### Alternative B: Timer Nodes

- **Description**: Each timed behavior uses a Godot `Timer` node child.
- **Pros**: Visual in editor; emits `timeout` signal (no polling)
- **Cons**: Timer nodes cannot live in Autoloads (no scene path); pausing requires each timer to be created under a PAUSABLE parent, which is easy to get wrong; hard to unit test without a SceneTree; individual ticks require one Timer per active status instance → object proliferation in wave with 10 enemies × 5 statuses
- **Rejection Reason**: Object proliferation + pause correctness risk + unit test difficulty. Float accumulator achieves the same result with zero overhead.

### Alternative C: SceneTree.create_timer()

- **Description**: `await get_tree().create_timer(duration).timeout` for one-shot delays; `while true: await tick_timer` for repeated events.
- **Pros**: Clean coroutine syntax; no boilerplate accumulator variable
- **Cons**: Pause behavior controlled by two optional args (`process_always`, `process_in_physics`) — incorrect defaults produce always-running timers; coroutine suspension makes unit testing in GUT very difficult; nested `await` chains are hard to debug
- **Rejection Reason**: Pause correctness risk; untestable in GUT without live SceneTree.

## Consequences

### Positive

- Pause correctness guaranteed by `PROCESS_MODE_PAUSABLE` — no per-system pause/resume code
- Accumulators are plain floats — directly readable in GUT tests without a running SceneTree
- Decrement pattern preserves sub-frame precision across all tick-based behaviors
- One mental model for all timing in the codebase

### Negative

- `_process()` runs every frame even when all timers are at 0 — negligible overhead for this project size but worth noting for future large-scale expansion
- Manual cancellation required: to cancel a timer early, set `_timer = 0.0` (or a sentinel like `-1.0`) and add a guard check

### Risks

- **Risk**: Developer forgets the pattern and uses `SceneTree.create_timer()`.
  **Mitigation**: Code review checklist item. ADR-0003 CI grep (`create_timer` in gameplay files) catches this.
- **Risk**: Accumulator variable name collisions in systems with many timers.
  **Mitigation**: Name convention: `_[behavior]_timer: float` (e.g., `_burn_timer`, `_freeze_timer`, `_dash_cooldown_timer`). StatusEffectsManager stores per-instance accumulators in a data class, not as separate script-level vars.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| prana-data.md | Burn ticks fire at 0.5s intervals; Regen at 1.0s intervals | Float accumulator in StatusEffectsManager with `burn_tick_rate = 0.5` decrement pattern |
| prana-data.md | Stun duration (0.8s min), Freeze duration (2.0s), Blind duration (2.0s) | Count-down accumulator in StatusEffectsManager per active status instance |
| spell-casting-effects.md | CAST_LOCKED window; Lightning Follow-Through 1.5s window | Count-down accumulators in SpellCastingEffects |
| player-controller.md | Dash cooldown; i-frame window (0.5s) | Count-down accumulators in PlayerController |
| enemy-ai.md | Contact damage interval (0.3s minimum) | Count-up accumulator in EnemyInstance |

## Performance Implications

- **CPU**: `_process(delta)` float addition — negligible (sub-nanosecond per accumulator per frame at 60fps)
- **Memory**: One `float` per active timer — negligible
- **Load Time**: No impact

## Validation Criteria

1. **AC-0004-01**: All status effect durations (Burn, Freeze, Blind, Regen, Stun) halt while `get_tree().paused = true` — verified by pausing mid-status in a GUT integration test and confirming the timer does not advance
2. **AC-0004-02**: No GDScript file in `src/` calls `SceneTree.create_timer()` for gameplay timing — verified by CI grep
3. **AC-0004-03**: No gameplay `Timer` node appears as a child of any Autoload — verified by scene inspection
4. **AC-0004-04**: Burn tick accumulator decrement test — `base_damage=10`, `burn_tick_rate=0.5s`, advance 4 ticks; cumulative timer error < 0.001s after tick 4

## Related Decisions

- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — defines which systems run `_process(delta)`
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — timers fire signals on tick; no polling
- [docs/architecture/architecture.md](../architecture.md) — Architecture Principle 3; Data Flow Scenario 1 (frame update path)
