# Control Manifest

> **Engine**: Godot 4.6 (Compatibility renderer, OpenGL 3.3 / D3D12 Windows)
> **Last Updated**: 2026-05-30
> **Manifest Version**: 2026-05-30
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013
> **Status**: Active — regenerate with `/create-control-manifest` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed this date when
created. `/story-readiness` compares a story's embedded version to this field to detect stories
written against stale rules. Always matches `Last Updated`.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs, technical
preferences, and engine reference docs. For the reasoning behind each rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, Autoload architecture, data catalogs, GameEnums, AudioSystem,
IsometricRoom rendering*

### Required Patterns

- **Use `TileMapLayer` with `TileSet.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC` for all environment tilemaps** — source: ADR-0001
- **Enable `Node2D.y_sort_enabled = true` on IsometricRoom and any parent of entity sprites** — source: ADR-0001
- **Keep gameplay logic in 2D cartesian coordinates; apply isometric projection at the rendering layer only** — source: ADR-0001
- **Tile size: 64×32px (2:1 dimetric). Sprite target: 32–48px tall** — source: ADR-0001
- **All character and enemy nodes must be children of a `y_sort_enabled = true` ancestor** — source: ADR-0001
- **Movement input is screen-space: WASD = screen up/down/left/right, not isometric grid directions** — source: ADR-0001
- **Register exactly 10 Autoloads in Project Settings in this fixed order: PranaCatalog (1), EnemyCatalog (2), GameStateManager (3), SceneManager (4), AudioSystem (5), HealthAndDamage (6), StatusEffectsManager (7), CombinationResolution (8), SpellCastingEffects (9), RunManager (10)** — source: ADR-0002
- **Autoload node name in Project Settings must exactly match the script's `class_name` declaration** — source: ADR-0002
- **Access Autoloads only from `_ready()`, deferred calls, or signal handlers** — source: ADR-0002
- **Use `call_deferred("add_child", node)` for runtime child instantiation inside Autoload `_ready()`** — source: ADR-0002
- **`main.tscn` is the project Main Scene (Project Settings → Application → Run). It is the permanent root and is never unloaded** — source: ADR-0005
- **CombatHUD lives in CanvasLayer layer 10 on main.tscn. `process_mode = PROCESS_MODE_ALWAYS`** — source: ADR-0005
- **SceneManager's `change_room()` must `await get_tree().process_frame` between `queue_free()` and `add_child()`** — source: ADR-0005
- **PranaGrid lives inside IsometricRoom.tscn as a CanvasLayer child (layer 1). Its state resets on each room load** — source: ADR-0005
- **`game_enums.gd`: `class_name GameEnums extends RefCounted`. NOT an Autoload. Contains only enum definitions** — source: ADR-0006
- **All GameEnums enum constants must have explicit integer assignments** — source: ADR-0006
- **New enum values must be appended. Existing integer assignments must never be reordered or renumbered** — source: ADR-0006
- **`PranaCatalog.get_type(id)` must always return `original.duplicate_deep()` — never a direct reference** — source: ADR-0008
- **`EnemyCatalog.get_type(id)` follows the identical immutability pattern** — source: ADR-0008
- **All startup guards use `push_error()`, not `assert()`. `assert()` is stripped from Godot 4.6 release builds** — source: ADR-0008
- **All audio from external systems goes through `AudioSystem.play_event(event_name: StringName)`** — source: ADR-0012
- **Music state machine transitions driven exclusively by GameStateManager signals — no polling** — source: ADR-0012
- **`AudioEventRegistry` loaded from `res://assets/data/audio_event_registry.tres` at startup — no hardcoded event data in GDScript** — source: ADR-0012
- **`AudioSystem._ready()` validates `is_instance_valid(GameStateManager)` with `push_error()` before connecting any signals** — source: ADR-0012
- **Dynamic `play_event()` keys built from variables must be wrapped: `StringName(variable)` — typed `Dictionary[StringName, ...]` does not match bare `String` keys** — source: ADR-0012

### Forbidden Approaches

- **Never access Autoloads in `_init()`, `@export` default expressions, or static initializers** — Autoloads are not in the scene tree during construction — source: ADR-0002
- **No Autoload may call methods on a higher-registered Autoload during its own `_ready()`** — use signal connections for deferred communication — source: ADR-0002
- **Never use `get_node("/root/SystemsRoot/...")` path-based system lookup** — class_name access is the approved pattern — source: ADR-0002
- **Never use ServiceLocator pattern for Autoload access** — GDScript `class_name` makes it redundant — source: ADR-0002
- **Never add `extends Node`, `@onready`, `@export`, `preload()`, or `load()` to `game_enums.gd`** — source: ADR-0006
- **Never register GameEnums as an Autoload** — no runtime state, wastes an Autoload slot — source: ADR-0006
- **Never define cross-system enum types in individual system files** — all shared enums belong in `game_enums.gd` — source: ADR-0006
- **Never return a direct reference from `PranaCatalog.get_type()` or `EnemyCatalog.get_type()`** — always `duplicate_deep()` — source: ADR-0008
- **Never use `duplicate(true)` (deprecated since Godot 4.5)** — use `duplicate_deep()` — source: ADR-0008
- **Never use `TileMap`** — use `TileMapLayer` (deprecated since 4.3) — source: ADR-0001, deprecated-apis.md
- **Never use `YSort` node** — use `Node2D.y_sort_enabled` property — source: deprecated-apis.md
- **Never instantiate `AudioStreamPlayer` nodes directly outside AudioSystem** — bypasses bus volume control — source: ADR-0012
- **Never call `AudioSystem.play_event()` with an AMB-bus event** — use `play_ambient()` — source: ADR-0012
- **Never connect AudioSystem to `wave_ended` as a music state trigger** — `preparation_started` is the authoritative trigger — source: ADR-0012
- **END cue `AudioStream` assets must be non-looping** — `finished` signal not emitted for looping streams; auto-transition to MAIN_MENU will never fire — source: ADR-0012

### Performance Guardrails

- **Audio SFX pool: 24 slots — handles worst-case ~20 simultaneous events** — source: ADR-0012
- **AudioSystem startup: 30 AudioStreamPlayer nodes + registry load; target < 1ms** — source: ADR-0012
- **Draw calls: < 200/frame** — source: technical-preferences.md

---

## Core Layer Rules

*Applies to: signal architecture, timer pattern, HP/damage pipeline, status effects, PranaGrid
input, spell stat broker, group/targeting convention*

### Required Patterns

- **Pattern 1 — Signals: use when a system announces an event and zero or more systems may care** — source: ADR-0003
- **Pattern 2 — Method calls: use when a system instructs another to perform an operation it owns** — source: ADR-0003
- **Connect to signals in `_ready()`, never in `_init()`** — source: ADR-0003
- **Use Callable syntax: `signal.connect(_handler)` or `signal.connect(_handler, CONNECT_ONE_SHOT)`** — source: ADR-0003
- **Scene nodes that connect to Autoload signals must disconnect in `_exit_tree()`** — source: ADR-0003
- **No circular Autoload-to-Autoload signal subscriptions** — source: ADR-0003
- **All in-game timing uses float delta accumulators in `_process(delta)`** — source: ADR-0004
- **Decrement accumulator by `tick_rate`, never reset to 0.0** — preserves sub-frame precision — source: ADR-0004
- **Process mode assignments**: StatusEffectsManager, SpellCastingEffects, PlayerController, EnemyInstance → `PROCESS_MODE_PAUSABLE`; CombatHUD, AudioSystem, GameStateManager → `PROCESS_MODE_ALWAYS` — source: ADR-0004
- **All damage goes through `HealthAndDamage.apply_damage(target, base_damage, element, source)`** — no direct HP modification — source: ADR-0007
- **All healing goes through `HealthAndDamage.apply_heal(target, heal_amount)`** — source: ADR-0007
- **`register_enemy(enemy, type_id)` called by WaveManager before `add_child()` — NOT in `EnemyInstance._ready()`** — source: ADR-0007
- **HP stored as `float` internally; damage numbers exposed as `int` via `roundi()`** — source: ADR-0007
- **`force_end_iframe_window()` is a TEST SEAM ONLY — never call from gameplay code** — source: ADR-0007
- **SpellCastingEffects is the sole owner of the wave's `SpellEffect` payload** — source: ADR-0009
- **All wave-scoped stat queries use `SpellCastingEffects.get_stat_bonus(stat_id: StringName) -> float`** — returns 0.0 if between waves — source: ADR-0009
- **`_current_spell_effect` cleared in `_on_preparation_started()` — no other Autoload caches `combo_resolved` for stats** — source: ADR-0009
- **PlayerController must call `add_to_group(&"player")` in `_ready()`** — source: ADR-0010
- **EnemyInstance must call `add_to_group(&"enemy")` in `_ready()`** — source: ADR-0010
- **Player lookup: `get_tree().get_first_node_in_group(&"player")` — cache result in `_ready()`; re-resolve only on null** — source: ADR-0010
- **Target discrimination: `is_in_group(&"player")` / `is_in_group(&"enemy")` in signal handlers and Area2D callbacks** — source: ADR-0010
- **Group names always as StringName literals: `&"player"`, `&"enemy"`** — source: ADR-0010
- **`apply_status(target, status_type, duration, spell_base_damage: float = 0.0)` — 4-arg signature. Burn requires non-zero `spell_base_damage`** — source: ADR-0011
- **`has_status(target, status_type)` — sole status query interface. No per-status helpers** — source: ADR-0011
- **SC&E must call `check_and_apply_shatter(target, base_damage)` before every DIRECT `apply_damage()` call** — source: ADR-0011
- **EnemyInstance must expose `apply_speed_modifier(multiplier: float)` and `apply_stun(duration: float)`** — source: ADR-0011
- **PlayerController and EnemyInstance must expose `is_alive() -> bool`** — source: ADR-0011
- **PranaGrid uses `_selected_slot_index: int` + `_gamepad_cursor: Control` overlay for gamepad navigation** — source: ADR-0013
- **Slot nodes: `mouse_filter = MOUSE_FILTER_STOP`, `focus_mode = FOCUS_ALL`; `_gui_input()` for click-to-place** — source: ADR-0013
- **Keyboard accessibility uses engine's built-in Tab/arrow focus system — no custom override** — source: ADR-0013
- **Input mode detection via `_input()` event type check — not polled in `_process()`** — source: ADR-0013
- **`_gamepad_cursor` must have `mouse_filter = MOUSE_FILTER_IGNORE`** — source: ADR-0013
- **Gamepad d-pad navigation wraps as 3×3 torus** — source: ADR-0013
- **Initialize `_gamepad_cursor` position in `_ready()` after `await get_tree().process_frame`** — source: ADR-0013
- **PranaGrid root node must be a plain `Control` or `Panel` — never a `Container` subclass** — source: ADR-0013
- **`GamepadCursor` anchor values must all be `0.0`** — source: ADR-0013

### Forbidden Approaches

- **Never read properties of another system in `_process()` to detect changes** — subscribe to signals — source: ADR-0003
- **Never use string-based signal connections: `connect("signal_name", self, "method")`** — deprecated since Godot 4.0 — source: ADR-0003, deprecated-apis.md
- **Never create circular Autoload-to-Autoload signal subscriptions** — source: ADR-0003
- **Never use `Timer` nodes for gameplay timing** — source: ADR-0004
- **Never use `SceneTree.create_timer()` for gameplay timing** — source: ADR-0004
- **Never use `OS.get_ticks_msec()`** — deprecated; use `Time.get_ticks_msec()` — source: ADR-0004, deprecated-apis.md
- **Never reset timer accumulator to `0.0` on tick — decrement by `tick_rate`** — source: ADR-0004
- **Never access HP state directly from another system** — only via `apply_damage()`, `apply_heal()`, and signals — source: ADR-0007
- **Never call `instance_from_id()` without null-checking the result** — freed node IDs return null, not crash — source: ADR-0007
- **Never add a node to both `&"player"` and `&"enemy"` groups simultaneously** — source: ADR-0010
- **Never use `get_nodes_in_group()` for per-frame player lookups** — cache the reference — source: ADR-0010
- **Never add per-status query helpers (`is_frozen()`, `is_blinded()`, etc.)** — `has_status()` is the sole interface — source: ADR-0011
- **SEM must not subscribe to `CombinationResolution.combo_resolved` for SpellEffect caching** — source: ADR-0011
- **Never call `grab_focus()` in gamepad navigation code paths** — source: ADR-0013
- **Never use engine focus state as source of truth for which slot the gamepad selected** — source: ADR-0013
- **Never poll `Input.is_action_pressed()` in `_process()` for input mode detection** — use `_input()` event dispatch — source: ADR-0013

### Performance Guardrails

- **SEM `_process()` tick loop: max ~105 active StatusInstances (15 enemies × 7 statuses) — O(T) float comparisons per frame** — source: ADR-0011
- **`apply_damage()` pipeline: O(1) per call — no per-frame overhead** — source: ADR-0007
- **EnemyAI group lookup: O(1) cached reference — `get_first_node_in_group()` at `_ready()` only** — source: ADR-0010

---

## Feature Layer Rules

*Applies to: EnemyAI behavior, WaveManager, secondary mechanics*

### Required Patterns

- **EnemyAI caches `_fayde_ref` at `_ready()` via `get_first_node_in_group(&"player")`. Re-resolve only when reference is null** — source: ADR-0010
- **All feature-layer wave stat queries go through `SpellCastingEffects.get_stat_bonus(stat_id)`** — no independent SpellEffect caching — source: ADR-0009
- **WaveManager calls `HealthAndDamage.register_enemy(enemy, type_id)` before `add_child(enemy)` on every spawn** — source: ADR-0007
- **EnemyType resource includes `scene: PackedScene` field — WaveManager spawns via this field** — source: ADR-0007

### Forbidden Approaches

- **Never subscribe to `CombinationResolution.combo_resolved` in feature-layer systems for stat caching** — source: ADR-0009
- **Never call `HealthAndDamage.register_enemy()` from `EnemyInstance._ready()`** — WaveManager is the registration authority — source: ADR-0007

---

## Presentation Layer Rules

*Applies to: CombatHUD, AudioSystem callers, PranaGrid visual, UI nodes*

### Required Patterns

- **CombatHUD uses Pattern 1 only — signal consumer. Never reads Autoload state directly** — source: ADR-0003
- **CombatHUD `process_mode = PROCESS_MODE_ALWAYS` — renders pause overlay while game is paused** — source: ADR-0004, ADR-0005
- **CombatHUD occupies CanvasLayer layer 10 — above game world (0), above PranaGrid (1)** — source: ADR-0005
- **`AudioSystem.play_event(&"event_name")` — use StringName literals at call sites** — source: ADR-0012
- **Dynamic event name variables must be wrapped: `StringName(my_event_var)`** — source: ADR-0012
- **Gamepad cursor overlay (`_gamepad_cursor`) has `z_index` above slot nodes** — source: ADR-0013
- **Keyboard accessibility focus indicator uses distinct styling from gamepad cursor** — source: ADR-0013

### Forbidden Approaches

- **Never reinstantiate CombatHUD on room load** — it is the same node instance for the entire session — source: ADR-0005
- **Never set CombatHUD as an Autoload** — it is a CanvasLayer child of main.tscn — source: ADR-0005
- **Never set `set_music_volume()` above -3.0 dB or `set_amb_volume()` above -10.0 dB** — enforce with clamps in setters — source: ADR-0012

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables / Functions | snake_case | `move_speed`, `take_damage()` |
| Signals | snake_case past tense | `health_changed`, `prana_collected` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `BASE_DAMAGE` |

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Draw calls | < 200/frame (2D Compatibility renderer) |
| Memory ceiling | < 512 MB (TBD after profiling) |

### Approved Libraries / Addons

- **GUT (Godot Unit Test)** — GDScript-native unit testing framework; integrated in Godot editor

### Forbidden APIs (Godot 4.6)

These APIs are deprecated or removed. Any suggestion to use them must be replaced:

| Forbidden | Use Instead | Since |
|-----------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` node | `Node2D.y_sort_enabled` property | 4.0 |
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate(true)` for nested resources | `duplicate_deep()` | 4.5 |
| `$NodePath` in `_process()` | `@onready var` cached reference | — |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | — |
| `Texture2D` in shader parameters | `Texture` base type | 4.4 |
| `rg --type gdscript` in shell | `rg --glob "*.gd"` | — |

Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints

- **`assert()` is stripped from Godot 4.6 release builds** — all runtime guards must use `push_error()`. `assert()` is only permitted for development-time invariants that must never reach production (e.g., PlayerController single-player group check at editor startup)
- **Typed `Dictionary[StringName, ...]` and `Dictionary[int, Array[...]]` require Godot 4.4+** — satisfied by the project's Godot 4.6 pin; do not backport to older versions
- **`ripgrep --type gdscript` is a hard error** — always use `--glob "*.gd"` to search GDScript files
- **Verification tests required before these implementation sprints**:
  - ADR-0001 (TileMapLayer isometric + Compatibility renderer) — before first IsometricRoom sprint
  - ADR-0006 (`.tres` enum int serialization) — before first `.tres` file authored
  - ADR-0008 (`duplicate_deep()` isolation) — before PranaCatalog implementation
  - ADR-0013 (PranaGrid dual-focus behavior) — blocking gate before PranaGrid implementation sprint
