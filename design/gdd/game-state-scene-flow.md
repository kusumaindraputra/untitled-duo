# Game State & Scene Flow

> **Status**: Approved (Design-Review passed 2026-05-22)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-22
> **Implements Pillar**: Infrastructure for all pillars — owns the Prep→Combat transition that Pillars 1–3 depend on

## Overview

Game State & Scene Flow is the top-level state machine and scene management layer
for The Last Cipher. It defines every game state the engine can be in and owns every
valid transition between them. No other system queries or stores the current game
state directly — this system is the single source of truth for when everything is
allowed to happen.

**MVP scope (6 states):** The MVP run is a single arena with multiple enemy waves
ending in a boss encounter. Each wave runs as a full Prep→Combat cycle — the player
returns to `PREPARATION_PHASE` between waves to re-arrange the Prana grid before
confirming the next wave's loadout. The arena ends when the boss is defeated
(`RUN_SUMMARY`) or Fayde dies (`DEATH_SCREEN`). Boss combat is handled via
`COMBAT_PHASE` with `is_boss: true` on the `combat_started` signal — no separate state
is needed because the state table rules are identical to a regular combat wave. MVP
states: `MAIN_MENU`, `PREPARATION_PHASE`, `COMBAT_PHASE`, `RUN_SUMMARY`,
`DEATH_SCREEN`, `PAUSED`.

**Vertical Slice extension:** VS adds `PATH_SELECTION`, `ROOM_TRANSITION`, `SHOP_PHASE`,
`REST_PHASE`, and `CIPHERS_TRIAL` — turning the single-arena loop into a full multi-room
roguelike. States and transitions tagged `[VS]` are out of MVP scope and must not be
built during the MVP milestone.

All state-conditional behavior is driven by state-change signals this system broadcasts.
The **CanvasLayer overlay pattern** (Core Rule 3) is the sanctioned mechanism for
delivering narrative content (memory fragments, Memo dialogue) without introducing
state changes.

## Player Fantasy

**The heartbeat (MVP — primary):** Players internalize the two-phase loop's rhythm
through repetition within a single run. Each wave cycles through the same two beats:
breath held during Preparation (peek, plan, arrange), then released into motion during
Combat. Multiple waves per run establish the pattern before the boss delivers the
culminating confrontation. The system gives the run its pulse.

**The final confrontation (MVP — climax):** After the waves, the boss arrives. The
pattern the player has practiced becomes the test. Victory delivers Fayde's first
recovered memory — the plot twist that recontextualizes the run just completed.

**The map reader's fantasy (`[VS]`):** The moment between rooms when the player surveys
the available paths and decides where to go next. The tension of a fork: a safe
Combat room versus a Cipher's Trial that could transform the run's power curve.
The player feels like an explorer, not a passenger.

**The calculated sacrifice (`[VS]`):** The sharp, clarifying feeling of a genuine
tradeoff — giving up something you've built (a reliable Prana type or a familiar
combo) to gain something that could be greater. Not a random event; a deliberate
wager with full information. The fantasy is the decision, not the outcome.

*Pillar alignment: "Every Run Tells a Different Story" (Pillar 1) — each wave in
MVP presents a different elemental challenge requiring a fresh prep decision; VS path
choices author the route. "Chaos Has Consequences" (Pillar 3) — VS Cipher's Trial
tradeoffs have legible, permanent consequences for the rest of the run.*

## Detailed Design

### Core Rules

1. Exactly one game state is active at any time. There is no "between states" —
   transitions are atomic. `PAUSED` does not replace the active gameplay state; the
   state machine stores a `_previous_state` field and restores it on resume.
   **Godot 4.6 PAUSED implementation:** `PAUSED` is implemented via
   `get_tree().paused = true`. Autoloads (`GameStateManager`, `SceneManager`) retain
   `process_mode = PROCESS_MODE_ALWAYS` (their default) and continue processing while
   paused. The pause overlay and its parent `CanvasLayer` must explicitly be set to
   `process_mode = PROCESS_MODE_ALWAYS` to remain interactive. All gameplay nodes
   (Player Controller, Enemy AI, Wave/Encounter) must be `process_mode =
   PROCESS_MODE_PAUSABLE` (the Godot default — confirm on implementation).
2. Only this system initiates state transitions. No other system changes the active
   state directly; they request or react via signals. **Exception:** other systems
   may emit internal events to which this system responds by initiating a transition
   (e.g., Wave/Encounter System emits `wave_cleared`, `all_waves_cleared`, or
   `boss_defeated`; Health & Damage emits a death event). These are input events to
   this system, not state changes made by those systems. Each such internal event must
   be named explicitly in the emitting system's own GDD.
3. Other systems respond to state changes through signals — they do not poll the
   current state. **Exception 1:** a system may read the state once at initialization
   to determine its starting configuration. **Exception 2 (Overlay pattern):**
   Narrative content — memory fragments, Memo dialogue — is delivered via CanvasLayer
   over an active state. Overlays do not constitute state changes and do not require
   state machine involvement. They are the only sanctioned form of non-state-change
   game-layer display. **Input routing requirement:** CanvasLayer overlay `Control`
   nodes must be configured to pass input through (`mouse_filter = MOUSE_FILTER_IGNORE`
   on non-interactive elements) so they do not silently block Prana Grid interaction
   during `PREPARATION_PHASE`. **Keyboard/gamepad focus:** Overlay appearance shifts
   keyboard/gamepad focus to the overlay's primary dismiss control. Dismissal restores
   focus to the previously focused element. The Lore Fragments system (System #21) uses
   this pattern exclusively; trigger logic for overlays is owned by Lore Fragments,
   not this system.
4. State transitions may carry a payload (e.g., `[VS]` Room Transition carries the
   destination node type, which determines the next state after arrival). When a
   transition with a required payload is requested with a null or unrecognized payload,
   the transition is rejected and a validation error is recorded.
5. `[VS]` Path Selection shows only immediately reachable next nodes — one step ahead.
   The player cannot see beyond their next choice. **Design rationale:** This is an
   intentional design constraint, not a scope limitation — it creates moment-to-moment
   tension at each fork and prevents the player from solving the floor as an
   optimization problem ahead of time.
6. `[VS]` Cipher's Trial commits the player on entry. The player must either make a
   tradeoff choice or pay a skip cost before returning to Path Selection. There is no
   free exit. **Pre-entry information requirement:** Before a player selects a Cipher's
   Trial node in Path Selection, the node map must display a non-color-only affordance
   communicating the committed-interaction nature of the Trial (e.g., an icon + text
   label visible without hover or selection required). The specific visual design is
   deferred to the VS UX specification for Path Selection; this information requirement
   is not deferrable.
7. Death in `COMBAT_PHASE` (including boss combat when `is_boss: true`) transitions
   immediately to `DEATH_SCREEN`. It does not pass through `RUN_SUMMARY`. "Immediately"
   means no intermediate **state** — but `death_started` is emitted as the **first**
   signal in the transition handler, before the state changes and before `run_ended`.
   This gives Audio System and Game Feel / Juice a signal to begin the death animation
   and audio fade at the correct moment. Signal ordering within the transition handler:
   (1) `death_started` emitted, (2) state updated to `DEATH_SCREEN`, (3) `run_ended(win:
   false)` emitted. Transition effects (fade, animation timing) are delivered by Game
   Feel / Juice (System #30), which must treat this as a required treatment item.
8. The persistent HUD layer is loaded once at run start and remains active across all
   in-run states. It is not reloaded between waves or rooms. **Godot 4.6 implementation
   pattern:** The HUD must survive SceneManager-initiated scene changes. Recommended
   pattern: HUD lives as a child of a persistent root scene that swaps sub-scenes
   rather than using `change_scene_to_file()`. Avoid the autoload-as-UI-host
   anti-pattern. `GameStateManager` itself is an autoload singleton registered at
   Project Settings → AutoLoad; accessible globally as `GameStateManager`.
   Scene loading is owned by a separate `SceneManager` autoload, not by
   `GameStateManager` directly. **AutoLoad registration order:** `GameStateManager`
   must be listed before `SceneManager` in Project Settings → AutoLoad. `SceneManager`
   must not call `GameStateManager` during its own `_ready()`. **Sub-scene swap frame
   boundary:** When `queue_free()` is used on an outgoing sub-scene, the node is not
   removed until the end of the current frame. `SceneManager` must either use
   `remove_child()` + `queue_free()` (guarantees immediate tree removal before the next
   add) or `await get_tree().process_frame` between freeing the old scene and adding
   the new one — do not add the next sub-scene in the same frame as `queue_free()`.

### States and Transitions

**Complete state list:**

| State | Description | Scope | Prana Grid | Movement | Enemy AI |
|-------|-------------|-------|-----------|----------|----------|
| `MAIN_MENU` | Title screen; no run active | MVP | Inactive | Inactive | Inactive |
| `PREPARATION_PHASE` | Wave peek active; player arranges Prana grid | MVP | **Editable** | Disabled | Inactive |
| `COMBAT_PHASE` | Active combat; Prana grid locked to confirmed loadout. `combat_started` payload: `is_boss: false` for regular waves, `is_boss: true` for boss combat. | MVP | Locked (visible) | **Active** | **Active** |
| `PAUSED` | Game paused; overlay over active state; `_previous_state` stored | MVP | Unchanged | Disabled | Paused |
| `RUN_SUMMARY` | Post-run stats screen (win) | MVP | Inactive | Inactive | Inactive |
| `DEATH_SCREEN` | Post-run stats screen (loss) | MVP | Inactive | Inactive | Inactive |
| `PATH_SELECTION` | One-step-ahead node map; player picks next destination | **[VS]** | Inactive | Inactive | Inactive |
| `ROOM_TRANSITION` | Travel animation; scene loads destination room | **[VS]** | Inactive | Disabled | Inactive |
| `SHOP_PHASE` | Prana shop; player buys/sells Prana from loot pool | **[VS]** | Inactive | Disabled | Inactive |
| `REST_PHASE` | Rest area; player recovers health or a depleted Prana slot | **[VS]** | Inactive | Disabled | Inactive |
| `CIPHERS_TRIAL` | Power tradeoff offer; player must resolve before exiting | **[VS]** | Inactive | Disabled | Inactive |

**Prana Grid sub-state definitions:**

| Grid permission | Meaning | Entry signal |
|----------------|---------|-------------|
| **Editable** | Grid rendered, fully interactive | `preparation_started` |
| **Locked (visible)** | Grid rendered, interaction blocked; shows committed loadout | `grid_locked` (emitted before `combat_started`, regardless of `is_boss` value) |
| **Inactive** | Grid hidden, not rendered | `grid_hidden` (emitted on `run_ended`; also on entry to PATH_SELECTION, SHOP_PHASE, REST_PHASE, CIPHERS_TRIAL [VS]) |

**Signal ordering:** Within any transition handler that emits both `grid_locked` and
`combat_started`, the ordering is deterministic: `grid_locked` fires first, then
`combat_started`. This applies to both regular wave combat (`is_boss: false`) and boss
combat (`is_boss: true`). This guarantees the Prana Grid is locked before the Player
Controller enables movement — no one-frame window where both are active.

**Additional signal ordering:** On the `MAIN_MENU → PREPARATION_PHASE` transition,
`run_started` fires first, then `preparation_started`. This guarantees Run Management
(#17) can initialize run data before the Prana Grid activates on `preparation_started`.

**Re-entrancy guard:** The signal-driven architecture creates a real re-entrancy hazard:
a `state_changed` handler in any downstream system can call back into
`_request_transition()` synchronously before the first transition handler returns (e.g.,
a Health & Damage handler responding to `state_changed` and immediately emitting a death
event). The re-entrancy guard in `GameStateManager` rejects the second request and logs
a debug error. This is not a theoretical concern — it is a direct consequence of using
signals as the universal coupling mechanism.

**MVP valid transitions:**

| From | To | Trigger |
|------|----|---------|
| `MAIN_MENU` | `PREPARATION_PHASE` | Player starts a new run |
| `PREPARATION_PHASE` | `COMBAT_PHASE` | Player confirms Prana loadout (grid non-empty); `combat_started(is_boss: false)` emitted |
| `COMBAT_PHASE` | `PREPARATION_PHASE` | Wave cleared, more regular waves remain (Wave/Encounter emits `wave_cleared`) |
| `COMBAT_PHASE` | `COMBAT_PHASE` | All regular waves cleared (Wave/Encounter emits `all_waves_cleared`); `combat_started(is_boss: true)` emitted — boss combat begins. This is a self-transition that reloads the state with new parameters. |
| `COMBAT_PHASE` | `DEATH_SCREEN` | Fayde's health reaches 0 (in regular or boss combat); `death_started` emitted first, then state changes, then `run_ended(win: false)` |
| `COMBAT_PHASE` | `RUN_SUMMARY` | Boss defeated while `is_boss: true` (Wave/Encounter emits `boss_defeated`) |
| `PREPARATION_PHASE` | `PAUSED` | Player triggers pause |
| `COMBAT_PHASE` | `PAUSED` | Player triggers pause |
| `PAUSED` | *(previous state)* | Player resumes; restores `_previous_state` |
| `PAUSED` | `MAIN_MENU` | Player quits run; `run_ended(win: false)` emitted before transitioning |
| `RUN_SUMMARY` | `MAIN_MENU` | Player returns to menu |
| `DEATH_SCREEN` | `MAIN_MENU` | Player returns to menu |

**VS additional transitions:**

| From | To | Trigger |
|------|----|---------|
| `MAIN_MENU` | `PATH_SELECTION` | Player starts a new run [replaces MAIN_MENU → PREPARATION_PHASE in VS] |
| `PATH_SELECTION` | `ROOM_TRANSITION` | Player selects a destination node; destination type passed as payload |
| `ROOM_TRANSITION` | `PREPARATION_PHASE` | Payload = Combat node |
| `ROOM_TRANSITION` | `SHOP_PHASE` | Payload = Shop node |
| `ROOM_TRANSITION` | `REST_PHASE` | Payload = Rest node |
| `ROOM_TRANSITION` | `CIPHERS_TRIAL` | Payload = Cipher's Trial node |
| `ROOM_TRANSITION` | `COMBAT_PHASE` | Payload = Boss node; `combat_started(is_boss: true)` emitted — boss combat begins without PREPARATION_PHASE |
| `COMBAT_PHASE` | `PATH_SELECTION` | Room cleared (Wave/Encounter emits `all_waves_cleared`; more rooms remain in floor) |
| `SHOP_PHASE` | `PATH_SELECTION` | Player exits shop |
| `REST_PHASE` | `PATH_SELECTION` | Player exits rest area |
| `CIPHERS_TRIAL` | `PATH_SELECTION` | Player makes a tradeoff choice, or pays skip cost and declines |

**Forbidden transitions (always rejected):**
- `PREPARATION_PHASE → COMBAT_PHASE` with empty Prana Grid — loadout must have ≥1 slot filled
- `COMBAT_PHASE → PREPARATION_PHASE` via any path other than Wave/Encounter `wave_cleared`
  signal — mid-wave re-arrangement is not permitted; only wave-end transitions are valid
- Any state → any state that skips an intermediate state
- Any system other than this one initiating a transition

**`[VS]` Cipher's Trial — option count by floor depth:**

| Condition | Options offered |
|-----------|----------------|
| `floor_depth_ratio < cipher_trial_depth_threshold_1` | 1 tradeoff option |
| `cipher_trial_depth_threshold_1 ≤ ratio < cipher_trial_depth_threshold_2` | 2 tradeoff options |
| `floor_depth_ratio ≥ cipher_trial_depth_threshold_2` | 3 tradeoff options |

The skip cost if the player declines all options is defined in Tuning Knobs (Section G).
Default: lose a fixed percentage of max HP (floors at 1 HP — see Edge Cases).

### Interactions with Other Systems

**Signal ownership note:** The Wave/Encounter System (System #12) owns wave progress
events. It emits `wave_cleared` when a regular wave completes and more regular waves
remain; this system receives it and transitions `COMBAT_PHASE → PREPARATION_PHASE`.
It emits `all_waves_cleared` when the last regular wave completes; this system receives
it and re-enters `COMBAT_PHASE` with `combat_started(is_boss: true)` to begin boss
combat (MVP), or transitions `COMBAT_PHASE → PATH_SELECTION` (VS, if more rooms remain
in the floor). It emits `boss_defeated` when the boss is destroyed; this system receives
it and transitions `COMBAT_PHASE → RUN_SUMMARY`, then emits `room_cleared`. No other
system emits these events.

**Complete signal contract:**

| Signal | Payload | Emitted When | Scope |
|--------|---------|-------------|-------|
| `state_changed` | `old_state`, `new_state` | Every transition | MVP |
| `run_started` | — | Entry to first in-run state (`PREPARATION_PHASE` in MVP; `PATH_SELECTION` in VS) | MVP |
| `preparation_started` | `wave_index: int`, `waves_remaining: int` | Entry to `PREPARATION_PHASE` | MVP |
| `wave_ended` | — | `COMBAT_PHASE` → `PREPARATION_PHASE` (wave cleared, more waves remain) | MVP |
| `combat_started` | `is_boss: bool` | Entry to `COMBAT_PHASE` (regular wave: `is_boss: false`); boss combat self-re-entry: `is_boss: true` | MVP |
| `grid_locked` | — | Emitted before `combat_started` (both `is_boss: false` and `is_boss: true`); Prana Grid locks on this signal | MVP |
| `grid_hidden` | — | Entry to `MAIN_MENU`, `RUN_SUMMARY`, `DEATH_SCREEN`; also `PATH_SELECTION`, `SHOP_PHASE`, `REST_PHASE`, `CIPHERS_TRIAL` [VS] | MVP |
| `game_paused` | — | Entry to `PAUSED` | MVP |
| `game_resumed` | — | Exit from `PAUSED`; `_previous_state` restored | MVP |
| `room_cleared` | — | `COMBAT_PHASE` → `RUN_SUMMARY` when boss defeated (`is_boss: true`) — MVP, fires once per run; `COMBAT_PHASE` → `PATH_SELECTION` (VS) | MVP |
| `death_started` | — | Emitted as the **first** signal in the `COMBAT_PHASE → DEATH_SCREEN` transition handler, before state changes and before `run_ended`. Marks the moment Fayde's death animation begins. | MVP |
| `run_ended` | `win: bool` | Entry to `RUN_SUMMARY` (`win: true`); entry to `DEATH_SCREEN` or `PAUSED → MAIN_MENU` quit (`win: false`) | MVP |
| `shop_entered` | — | Entry to `SHOP_PHASE` | [VS] |
| `rest_entered` | — | Entry to `REST_PHASE` | [VS] |
| `ciphers_trial_entered` | `option_count: int` | Entry to `CIPHERS_TRIAL` | [VS] |
| `ciphers_trial_resolved` | `choice_accepted: bool` | Exit from `CIPHERS_TRIAL` | [VS] |

**`room_cleared` naming note (MVP):** In MVP there is one arena, not rooms. `room_cleared`
fires exactly once per MVP run — when the boss is defeated (`is_boss: true` combat ends
in victory) and the arena is complete. Downstream MVP GDD authors should treat
`room_cleared` as "arena/run completed" in MVP context. The VS semantics (room-to-room)
apply when PATH_SELECTION exists.

**What each system does with these signals (provisional — confirmed when each GDD is authored):**
- **Prana Grid** — shows editable on `preparation_started` (receives `wave_index` and
  `waves_remaining` for potential wave-count display); locks visible on `grid_locked`;
  hides on `grid_hidden`
- **Player Controller** — enables movement on `combat_started` (both `is_boss: false`
  and `is_boss: true`); disables otherwise; pauses on `game_paused`; restores on
  `game_resumed`
- **Wave/Encounter System** — begins wave peek on `preparation_started`; spawns regular
  wave on `combat_started(is_boss: false)`; spawns boss wave on `combat_started(is_boss:
  true)`; emits internal `wave_cleared` (more waves remain) → this system transitions
  to `PREPARATION_PHASE`; emits internal `all_waves_cleared` (all regular waves done) →
  this system re-enters `COMBAT_PHASE` with `is_boss: true`; emits internal
  `boss_defeated` → this system transitions to `RUN_SUMMARY`
- **Health & Damage** — tracks damage in `COMBAT_PHASE` (both `is_boss: false` and
  `is_boss: true`); emits an internal death event → this system receives it and
  transitions to `DEATH_SCREEN`
- **Combat HUD** — shows full HUD on `combat_started` (uses `is_boss` flag to surface
  boss-specific UI elements when `is_boss: true`); shows prep HUD layout on
  `preparation_started` (uses `wave_index` and `waves_remaining` for escalation display);
  shows wave-between indicator on `wave_ended`; shows pause overlay on `game_paused`;
  restores on `game_resumed`; hides on `run_ended`
- **Run Management** — initializes run data on `run_started`; records wave result on
  `wave_ended`; records arena result on `room_cleared`; finalizes on `run_ended`
- **Pause Menu (#25)** — renders MVP pause overlay (Resume + Quit to Menu) on
  `game_paused`; dismisses on `game_resumed`; Quit to Menu triggers `run_ended(win:
  false)` then transitions to `MAIN_MENU`
- **Audio System** — enters DYING audio state (music fades to near-silence) on `death_started`; transitions to END_DEFEAT music state on `run_ended(win: false)`; transitions music state on `run_started`, `preparation_started`, `combat_started`, `run_ended(win: true)`
- **Lore Fragments / Memo** — uses the sanctioned CanvasLayer overlay pattern (Core Rule 3,
  Exception 2); overlay Control nodes configured with `mouse_filter = MOUSE_FILTER_IGNORE`
  to pass input through; trigger logic owned entirely by the Lore Fragments GDD

## Formulas

### `[VS]` Cipher's Trial Option Count

*This formula is VS-scope — not applicable to the MVP single-arena run.*

`option_count` is determined by comparing `floor_depth_ratio` against two configurable
threshold tuning knobs:

```
IF floor_depth_ratio < cipher_trial_depth_threshold_1:
    option_count = 1
ELIF floor_depth_ratio >= cipher_trial_depth_threshold_1 AND floor_depth_ratio < cipher_trial_depth_threshold_2:
    # T1 is inclusive — this branch fires when ratio equals T1 exactly (confirmed by AC-VS-04)
    option_count = 2
ELSE:
    option_count = 3
```

**`nodes_completed` definition:** `nodes_completed` is the count of nodes fully resolved
**before** entering the Trial node — the Trial node itself is not counted at entry.
Example: entering Trial as the 9th node on a 12-node floor → `nodes_completed = 8`,
`floor_depth_ratio = 8/12 = 0.667`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Floor depth ratio | `floor_depth_ratio` | float | 0.0 – 1.0 | `nodes_completed / total_floor_nodes` at Trial entry; `nodes_completed` excludes the Trial node being entered |
| Lower threshold | `cipher_trial_depth_threshold_1` | float | 0.1 – 0.5 | 1→2 option boundary (default: 0.33) |
| Upper threshold | `cipher_trial_depth_threshold_2` | float | 0.5 – 0.9 | 2→3 option boundary (default: 0.67; must be strictly > T1) |
| Option count | `option_count` | int | 1 – 3 | Number of tradeoff pairs presented to the player |

**Output with default thresholds:**
- `0.0 ≤ ratio < 0.33` → 1 option
- `0.33 ≤ ratio < 0.67` → 2 options
- `ratio ≥ 0.67` → 3 options

**Precondition:** `total_floor_nodes ≥ 1` is a required guarantee from Run Management
(System #17). If `total_floor_nodes = 0` occurs (a bug), `option_count` defaults to 1
and a fatal error is logged — no division is attempted.

**Threshold guard:** `cipher_trial_depth_threshold_2` must be strictly greater than
`cipher_trial_depth_threshold_1`. If T1 ≥ T2 (including T1 = T2, which produces a
zero-width 2-option band where `option_count = 2` is never returned), the formula logs
an error and defaults to T1 = 0.33, T2 = 0.67. **Minimum gap guard:** If
`cipher_trial_depth_threshold_2 - cipher_trial_depth_threshold_1 < 0.1`, log a warning
and snap to defaults — a gap smaller than 0.1 creates a statistically unreachable
2-option band on typical floor sizes (e.g., T1 = 0.1, T2 = 0.11 passes the strict-
greater-than check but is degenerate).

**Example (early floor):** 3 nodes completed of 12. `floor_depth_ratio = 0.25`.
`0.25 < 0.33` → `option_count = 1`.

**Example (mid floor):** 5 nodes completed of 12. `floor_depth_ratio = 0.417`.
`0.33 ≤ 0.417 < 0.67` → `option_count = 2`.

**Example (late floor):** 9 nodes completed of 12. `floor_depth_ratio = 0.75`.
`0.75 ≥ 0.67` → `option_count = 3`.

**Boundary note:** At `floor_depth_ratio = 1.0` (all nodes completed before entering
Trial — e.g., Trial is the last node on the floor), `1.0 ≥ 0.67` → `option_count = 3`.
This is the intended behavior for a final-node Trial.

*All other state transitions are discrete decisions per the transition tables — no formula required.*

## Edge Cases

- **If Fayde's health reaches 0 during `COMBAT_PHASE`** (including boss combat when
  `is_boss: true`): Transition to `DEATH_SCREEN` immediately. No intermediate states.
  Any in-progress wave spawns and enemy AI are halted by the state change signal.
  Transition effects (fade, death animation timing) are delegated to Game Feel / Juice
  (System #30) via the `run_ended` signal — System #30 must treat this as a required
  treatment item.

- **If the player attempts to confirm their Prana loadout with an empty grid:** The
  transition to `COMBAT_PHASE` is blocked. The confirm button is disabled until at
  least one slot is filled. The player receives a visible feedback message explaining
  the requirement — silent button disable alone is insufficient for the 7+ target
  audience. (UI affordance specification belongs to Prana Grid GDD #1 and Combat HUD
  GDD #22; this system owns only the transition rejection.)

- **If `preparation_phase_time_limit_sec > 0` and the timer reaches zero during
  `PREPARATION_PHASE`:** If the Prana Grid has at least one slot filled, the transition
  to `COMBAT_PHASE` fires automatically — equivalent to the player pressing confirm with
  the current grid state. If the grid is empty at timer expiry, the transition is blocked
  (the empty-grid rule applies); the timer halts and the player must fill at least one
  slot. The timer does not resume after an empty-grid block.

- **If the player triggers pause during `PREPARATION_PHASE` or `COMBAT_PHASE`** (any
  `is_boss` value): The active state is stored in `_previous_state`; the machine enters
  `PAUSED` via `get_tree().paused = true`. The game world freezes (see Core Rule 1 for
  `process_mode` requirements). On resume, `_previous_state` is restored. Pause is not
  available from `MAIN_MENU`, `RUN_SUMMARY`, or `DEATH_SCREEN` — those states have no
  ongoing game world to suspend.

- **`[VS]` If a state transition is requested while `ROOM_TRANSITION` is already active**:
  The request is rejected until the transition completes. If two simultaneous requests
  arrive, the first wins; the second is dropped with a debug log.

- **`[VS]` If a Cipher's Trial tradeoff option's cost would reduce Fayde's HP to 0 or
  below**: That option is disabled and unselectable. The player may still choose other
  options or pay the skip cost. A disabled option is shown with a visual affordance that
  does not rely on color alone (required for colorblind accessibility).

- **`[VS]` If Cipher's Trial skip cost would reduce Fayde's health to 0 or below**: The
  skip is still permitted. Fayde's health floors at 1 HP — the skip cost cannot kill him.
  This prevents a soft-lock where the only exit from the state would result in death.
  **At 1 HP (intended soft-lock prevention behavior):** All tradeoff options are disabled
  (each would reduce HP to ≤ 0) AND the skip costs 0 net HP (floors at 1). The player
  exits `CIPHERS_TRIAL` for free — this is the correct behavior. Note:
  `cipher_trial_skip_cost_hp` has no effective cost below a minimum HP threshold; tuning
  the skip cost higher does not force engagement when the player is at 1 HP.

- **`[VS]` If all available Path Selection options lead to the Boss node**: Path Selection
  displays only the Boss option. No special handling needed — valid end-of-floor state.

- **`[VS]` If a floor has 0 nodes completed when Cipher's Trial is entered** (Trial as
  the first node): `floor_depth_ratio = 0.0`. `0.0 < T1` → `option_count = 1`.
  Handled correctly by the formula.

- **`[VS]` If a floor has all nodes completed when Cipher's Trial is entered** (Trial
  as the last node): `floor_depth_ratio = 1.0`. `1.0 ≥ 0.67` → `option_count = 3`.
  Correct and intended — maximum options at maximum floor depth.

- **`[VS]` If `total_floor_nodes = 0`** (bug — Run Management must guarantee ≥ 1 node):
  `option_count` defaults to 1. A fatal error is logged. Division by zero is
  never attempted.

- **If `run_ended` triggers from both win and loss simultaneously** (a bug): First
  transition wins; second is logged as an error. By design these are mutually exclusive.

## Dependencies

### Upstream Dependencies

None. This is a Foundation layer system — it has no runtime dependencies on any
other system.

### Downstream Dependents

| System | What it depends on from this system | Dependency type | Scope |
|--------|-------------------------------------|----------------|-------|
| Prana Grid (#1) | `preparation_started`, `grid_locked`, `grid_hidden` | Hard | MVP |
| Combination Resolution (#2) | `preparation_started`, `combat_started` (via Prana Grid) | Soft | MVP |
| Spell Casting & Effects (#3) | `combat_started` (both `is_boss: false` and `is_boss: true`) | Hard | MVP |
| Player Controller (#5) | `combat_started` (both `is_boss: false` and `is_boss: true`), `preparation_started`, `game_paused`, `game_resumed` | Hard | MVP |
| Health & Damage (#6) | `combat_started` (both `is_boss: false` and `is_boss: true`); death event → triggers `DEATH_SCREEN` | Hard | MVP |
| Enemy AI (#8) | `combat_started` (uses `is_boss` flag), `room_cleared`, `game_paused`, `game_resumed` | Hard | MVP |
| Wave / Encounter System (#12) | `preparation_started` (with `wave_index`, `waves_remaining` payload), `combat_started` (both `is_boss: false` and `is_boss: true`); emits internal `wave_cleared`, `all_waves_cleared`, `boss_defeated` → triggers transitions | Hard | MVP |
| Obstacle System (#14) | `preparation_started` (for wave peek display) | Soft | MVP |
| Prana Drop / Loot (#16) | `room_cleared` | Hard | MVP |
| Run Management (#17) | `run_started`, `wave_ended`, `room_cleared`, `run_ended` | Hard | MVP |
| Game Feel / Juice (#30) | `state_changed`; required to handle death-to-`DEATH_SCREEN` transition effect | Soft | MVP |
| Combat HUD (#22) | `preparation_started` (with `wave_index`, `waves_remaining` payload), `combat_started` (uses `is_boss` flag), `wave_ended`, `run_ended`, `game_paused`, `game_resumed` | Hard | MVP |
| Run Summary Screen (#23) | `run_ended(win: true)` | Hard | MVP |
| Main Menu (#24) | Scene management — `SceneManager` autoload loads/unloads Main Menu scene in response to this system's state changes | Hard | MVP |
| Pause Menu (#25) | `game_paused`, `game_resumed`; owns pause overlay UI (MVP: Resume + Quit to Menu; full settings/options in VS GDD #25) | Hard | MVP |
| Shop Phase (VS sub-feature of Run Management #17) | `shop_entered`; `PATH_SELECTION` re-entry on exit | Hard | [VS] |
| Rest Phase (VS sub-feature of Run Management #17) | `rest_entered`; `PATH_SELECTION` re-entry on exit | Hard | [VS] |
| Cipher's Trial (VS sub-feature of Run Management #17) | `ciphers_trial_entered`, `ciphers_trial_resolved` | Hard | [VS] |
| Lore Fragments (#21) | Overlay pattern (Core Rule 3, Exception 2); input pass-through required; no state signals required | Soft | Alpha |

**Hard** = the dependent system cannot function without this signal.
**Soft** = the dependent system is enhanced by this signal but can fall back.

### Interface Constraints for Downstream GDDs

When authoring any downstream GDD, it must:
1. Reference this GDD's signal names exactly as listed in Section C. Use `grid_locked`
   and `grid_hidden` (not former names `grid_show_locked` / `grid_hide`).
2. Never store or duplicate the active game state — always derive from signals.
3. Define which signals it connects to and what behavior it enables/disables per signal.
4. If it emits internal events this system responds to (e.g., `wave_cleared`,
   `boss_defeated`, death event), name those internal events explicitly in its own GDD.
5. If it implements any UI state (including pause overlay), document the full keyboard
   and gamepad navigation model — all UI must be fully keyboard-navigable per
   `technical-preferences.md`.
6. **Prana Grid GDD (#1) must define the full keyboard and gamepad navigation model
   for grid interaction before MVP `PREPARATION_PHASE` implementation proceeds.** If
   GDD #1 also defers this model, the producer must resolve the ownership gap as a
   cross-GDD blocker — there must be a single named owner before any Prep Phase
   implementation begins.

## Tuning Knobs

| Knob | Default | Safe Range | Effect of Low → High | Scope |
|------|---------|-----------|----------------------|-------|
| `preparation_phase_time_limit_sec` | 0 (no limit) | 0–60 | 0 = no time pressure. **Deliberate design choice for MVP:** unlimited prep time is an intentional accessibility affordance for the 7+ target audience — tension comes from wave composition and enemy visibility, not clock pressure. >0 = urgency added; timer expiry auto-confirms current grid (blocks if grid empty — see Edge Cases). Not recommended for MVP. | MVP |
| `room_transition_duration_sec` | 0.5 | 0.2–1.5 | Low: abrupt. High: slow, can feel like a loading screen. Applies only when `ROOM_TRANSITION` state exists. | [VS] |
| `path_selection_choices_per_step` | 3 | 2–4 | Low: fewer forks, faster traversal. High: more routing choices, richer decisions, risk of decision paralysis. Default 3 provides at least one meaningful alternative at every fork. Values above 3 not recommended. | [VS] |
| `cipher_trial_depth_threshold_1` | 0.33 | 0.1–0.5 | Shifts when the 1→2 option upgrade occurs in the floor. | [VS] |
| `cipher_trial_depth_threshold_2` | 0.67 | 0.5–0.9 | Shifts when the 2→3 option upgrade occurs. Must be strictly > `cipher_trial_depth_threshold_1`. | [VS] |
| `cipher_trial_skip_cost_hp` | 15% of max HP | 5%–40% | Low: skipping is nearly free. High: skipping is punishing, forces engagement even when options are bad. | [VS] |

**Note on `cipher_trial_skip_cost_hp`:** The skip cost floors at 1 HP regardless of
this value (Edge Case — the skip cannot kill Fayde). Re-express as a flat value once
the Health & Damage GDD (System #6) defines max HP.

**Note on depth thresholds:** `cipher_trial_depth_threshold_2` must be strictly greater
than `cipher_trial_depth_threshold_1`. If T1 ≥ T2, the formula logs an error and
defaults to T1 = 0.33, T2 = 0.67.

## Visual/Audio Requirements

[To be designed — MVP state transitions should include screen flash/fade cues specified
in the Game Feel / Juice GDD (System #30). The death-to-`DEATH_SCREEN` transition is a
required treatment item for System #30. `PAUSED` state requires a pause overlay visual
design (MVP: Resume + Quit to Menu; full design in Pause Menu GDD #25). VS states
require a full node map visual design pass.]

**Content constraints (all-ages — hard, applies to all states):** All visual elements
must be appropriate for ages 7+. `DEATH_SCREEN` must not display blood, distressing
imagery, or threatening language. Failure framing must be consistent with the game's
"mysterious, not threatening" tone established in `design/gdd/game-concept.md`. Enemy
defeat uses the Prana bloom dissolve convention; Fayde's death state must have an
equivalent age-appropriate visual treatment — specific design deferred to Game Feel /
Juice GDD #30, which must treat this as a required item alongside the death transition.

## UI Requirements

All MVP menu states (`MAIN_MENU`, `RUN_SUMMARY`, `DEATH_SCREEN`) must be fully navigable
via keyboard. Navigation model (tab order, focus management, confirm/cancel bindings) is
specified in the UX spec for each screen. **Implementation must not proceed on any MVP
menu state until its UX spec is authored** (`/ux-design main-menu`, `/ux-design run-summary`,
`/ux-design death-screen`).

`PAUSED` state UI (MVP): single action — resume. Full Pause Menu UI (settings, quit, etc.)
is VS scope (Pause Menu GDD #25).

[VS design artifacts required before VS states can be implemented:
(1) Path Selection node map information architecture — how node types are visually
distinguished, including required non-color-only pre-entry affordance for Cipher's Trial
nodes. (2) Cipher's Trial pre-entry consent pattern — committed-interaction rule must be
communicated before node selection, not on entry. (3) Gamepad navigation model for both
Path Selection and Cipher's Trial.]

## Acceptance Criteria

*Test type key: [U] = Automated unit test | [I] = Automated integration test |
[M] = Manual QA walkthrough | [V] = Visual/screenshot review | [CI] = CI lint/static check*

**"A validation error is recorded" definition (used in multiple ACs):** `push_error()` is
called with a message containing `[GameStateManager]`, observable in GUT tests via
`assert_error_logged()` or the equivalent GUT assertion. Dynamic dispatch via `call()` or
`set()` with string-named methods is also forbidden by convention — the grep CI check is
best-effort and does not catch string-based calls.

**"Validation error is recorded" must be verifiable in every [U] test that asserts it.**
If GUT's error-log assertion is not available, the implementer must expose a testable
`last_error: String` property on `GameStateManager` and update these ACs to assert
against it.

### MVP Acceptance Criteria

**[U] AC-01** — GIVEN the game state machine is in `COMBAT_PHASE`, WHEN
`_on_all_waves_cleared()` is called, THEN `get_active_state()` returns `COMBAT_PHASE`
and `combat_started` is emitted with `is_boss: true` before the handler returns — no
`await`, `yield`, or deferred call is used in the transition path.
*(Boss combat is a self-transition on `COMBAT_PHASE`, not a new state.)*

**[U] AC-01b** — GIVEN the active state is `COMBAT_PHASE` and `is_boss: true` is the
current combat mode, WHEN `_on_boss_defeated()` is called, THEN `get_active_state()`
returns `RUN_SUMMARY` and `run_ended(win: true)` is emitted exactly once.

**[I] AC-02** — GIVEN Fayde's health reaches 0 during `COMBAT_PHASE` (regardless of
`is_boss` value), WHEN the death event fires from the Health & Damage system, THEN the
active state transitions to `DEATH_SCREEN` — not `RUN_SUMMARY`.

**[U] AC-03** — GIVEN the active state is `MAIN_MENU`, WHEN `start_run()` is called,
THEN the `run_started` signal is emitted exactly once before the call returns, and
`get_active_state()` returns `PREPARATION_PHASE`.

**[U] AC-03b** — GIVEN the active state is `PREPARATION_PHASE`, WHEN `start_run()` is
called again, THEN `run_started` is NOT emitted and `get_active_state()` remains
`PREPARATION_PHASE`.

**[U] AC-04a** — GIVEN the active state is `COMBAT_PHASE`, WHEN
`_request_transition(PREPARATION_PHASE)` is called directly (not via the
`_on_wave_cleared` signal handler), THEN the state remains `COMBAT_PHASE` and a
validation error is recorded.
*(Mid-wave re-arrangement forbidden — Core Rule, Forbidden Transitions.)*

**[CI] AC-04b** — No code path outside `_on_wave_cleared()` in
`src/core/game_state_manager.gd` shall call `_request_transition(PREPARATION_PHASE)`
while `COMBAT_PHASE` is active. Enforced via Grep-based CI check on every push to
`main`.
*(Complements AC-04a: CI check catches callers the unit test cannot enumerate.)*

**[U] AC-05** — GIVEN the active state is `PREPARATION_PHASE` and the Prana Grid
reports zero filled slots, WHEN `_request_transition(COMBAT_PHASE)` is called, THEN
the state remains `PREPARATION_PHASE` and the transition is rejected.
*(Requires Prana Grid stub that reports empty state.)*

**[CI] AC-06** — No GDScript file outside `src/core/game_state_manager.gd` shall write
to `_active_state` directly or call `_request_transition()` or `set_active_state()`.
Enforced via Grep-based CI check on every push to `main`.
*(Reclassified from [U] — GDScript has no `get_caller()` API; runtime caller-identity
is not testable in GUT. The CI lint rule is the sole enforcement mechanism.)*

**[U] AC-07** — GIVEN a `state_changed` signal handler connected to `GameStateManager`
calls `_request_transition(Y)` synchronously during a transition to state X (simulated
by calling `_on_state_changed` from within the first transition handler via a connected
test stub), WHEN that recursive call is processed, THEN the second request is rejected,
a debug error is recorded, and `get_active_state()` equals X after both calls return.
*(Re-entrancy guard. The scenario is reachable via synchronous signal chains — e.g., a
Health & Damage handler responding to `state_changed` by emitting a death event that
triggers `_request_transition(DEATH_SCREEN)`. A test stub that connects to `state_changed`
and calls `_request_transition(Y)` constructs this scenario in GUT without multi-threading.)*

**[M] AC-08** — GIVEN a full MVP run playthrough transitions through `PREPARATION_PHASE`,
`COMBAT_PHASE` (regular waves and boss via `is_boss: true`), and `RUN_SUMMARY` or
`DEATH_SCREEN`, WHEN each transition occurs, THEN: (a) the persistent HUD node is
present in the scene tree at every state (`is_inside_tree()` = true); (b) the HUD
health and Prana display values match Fayde's actual state at each transition.
*(Manual walkthrough — visual verification; Advisory. HUD scene-tree presence is an
integration concern owned by SceneManager, not a unit-testable state machine assertion.)*

**[U] AC-10** — GIVEN the active state is `COMBAT_PHASE`, WHEN `_on_wave_cleared()` is
called and Wave/Encounter reports more regular waves remain, THEN `get_active_state()`
returns `PREPARATION_PHASE` and `wave_ended` is emitted.
*(Wave re-prep cycle.)*

**[U] AC-11** — GIVEN the active state is `PREPARATION_PHASE` or `COMBAT_PHASE` (any
`is_boss` value), WHEN pause is triggered, THEN `get_active_state()` returns `PAUSED`,
`game_paused` is emitted, and `_previous_state` equals the state before the pause.

**[U] AC-12** — GIVEN the active state is `PAUSED`, WHEN resume is triggered, THEN
`get_active_state()` returns the value of `_previous_state` and `game_resumed` is emitted.

**[U] AC-13** — GIVEN the active state is `MAIN_MENU`, `RUN_SUMMARY`, or `DEATH_SCREEN`,
WHEN pause is triggered, THEN the state remains unchanged and no `game_paused` signal
is emitted.
*(Pause not available outside gameplay states.)*

**[I] AC-14** — GIVEN a `COMBAT_PHASE → COMBAT_PHASE` self-transition fires (boss combat
entry: `all_waves_cleared`), WHEN the transition handler completes, THEN `grid_locked`
was emitted before `combat_started(is_boss: true)` in the same transition handler.
*(Signal ordering — deterministic grid-lock-before-movement guarantee; Core Rule signal
ordering note. Applies to both regular wave entry and boss combat entry.)*

**[M] AC-15** — GIVEN a full MVP run playthrough and the boss is defeated (boss combat
`is_boss: true` ends in victory), WHEN `RUN_SUMMARY` is displayed, THEN the Memo /
memory fragment lore overlay (plot twist) has fired at or before the summary screen.
*(Manual walkthrough — narrative delivery gate; Advisory.)*

**[U] AC-16** — GIVEN `preparation_phase_time_limit_sec > 0`, the active state is
`PREPARATION_PHASE`, and the Prana Grid stub reports at least one filled slot, WHEN the
preparation timer reaches zero, THEN `get_active_state()` returns `COMBAT_PHASE`.
*(Timer auto-confirm happy path — documented in Edge Cases, previously without AC.)*

**[U] AC-17** — GIVEN `preparation_phase_time_limit_sec > 0`, the active state is
`PREPARATION_PHASE`, and the Prana Grid stub reports zero filled slots, WHEN the
preparation timer reaches zero, THEN the state remains `PREPARATION_PHASE` and the
timer is halted (not running). The empty-grid block applies; the timer does not resume.
*(Timer halt on empty grid at expiry — documented in Edge Cases, previously without AC.)*

**[U] AC-18** — GIVEN the active state is `COMBAT_PHASE` and Fayde's health reaches 0,
WHEN the death event handler runs, THEN `run_ended(win: false)` is emitted exactly once
and `get_active_state()` returns `DEATH_SCREEN`.
*(Complements AC-01b which covers `run_ended(win: true)` on boss defeat. Both payloads
must be tested — a bug emitting `win: true` on death would pass AC-01b and AC-02.)*

**[U] AC-19** — GIVEN the active state is `PAUSED`, WHEN "Quit to Menu" is triggered,
THEN `run_ended(win: false)` is emitted exactly once and `get_active_state()` returns
`MAIN_MENU`.
*(PAUSED → MAIN_MENU quit path. Distinct from death — no scene transition to DEATH_SCREEN.)*

### `[VS]` Acceptance Criteria

*Required before VS-scope states are implemented.*

**[U] AC-VS-payload-guard** — GIVEN `_request_transition(ROOM_TRANSITION)` is called
with `node_type = null`, WHEN the request is processed, THEN the transition is rejected
and a validation error is recorded.
*(Payload error-path — Core Rule 4. ROOM_TRANSITION only exists in VS scope; this AC
requires VS states to be defined as valid enum values.)*

**[I] AC-VS-01** — GIVEN the game is in `COMBAT_PHASE` with `is_boss: true` active and
the full Boss Encounter System (#11) is integrated, WHEN Fayde's health reaches 0 via
the Boss Encounter system's damage path, THEN the active state transitions to
`DEATH_SCREEN` — not `RUN_SUMMARY`.
*(VS integration test — validates Boss Encounter System (#11) integration with death
path. MVP equivalent: AC-02.)*

**[I] AC-VS-02** — GIVEN the game is in `COMBAT_PHASE` with `is_boss: true` active and
the full Boss Encounter System (#11) is integrated, WHEN the boss defeat event fires
via the Boss Encounter system's defeat path, THEN the active state transitions to
`RUN_SUMMARY` — not `DEATH_SCREEN`.
*(VS integration test — validates Boss Encounter System (#11) integration with victory
path. MVP equivalent: AC-01b.)*

**[U] AC-VS-03** — GIVEN `floor_depth_ratio = 0.25` (below T1 = 0.33), WHEN the
Cipher's Trial option count formula is evaluated, THEN `option_count = 1`.

**[U] AC-VS-04** — GIVEN `floor_depth_ratio = 0.33` (at the T1 lower boundary), WHEN
evaluated, THEN `option_count = 2`.
*(Boundary pair — value AT threshold transitions to 2.)*

**[U] AC-VS-05** — GIVEN `floor_depth_ratio = 0.329` (just below T1), WHEN evaluated,
THEN `option_count = 1`.
*(Boundary pair — value BELOW threshold stays at 1.)*

**[U] AC-VS-06** — GIVEN `floor_depth_ratio = 0.67` (at the T2 upper boundary), WHEN
evaluated, THEN `option_count = 3`.

**[U] AC-VS-07** — GIVEN `floor_depth_ratio = 0.669` (just below T2), WHEN evaluated,
THEN `option_count = 2`.

**[U] AC-VS-08** — GIVEN `total_floor_nodes = 0` (bug condition), WHEN `option_count`
is requested, THEN `option_count = 1` and a fatal error is logged. No division by
zero is attempted.

**[U] AC-VS-08b** — GIVEN `floor_depth_ratio = 1.0` (all nodes completed before Trial
entry), WHEN evaluated, THEN `option_count = 3`.
*(Last-node Trial scenario — ratio = 1.0 must not degenerate.)*

**[I] AC-VS-09** — GIVEN a floor with 12 total nodes and 9 nodes fully resolved
**before** the Trial node is entered (`nodes_completed = 9`, `floor_depth_ratio =
9/12 = 0.75 ≥ 0.67`), WHEN the player enters Cipher's Trial, THEN exactly 3 tradeoff
options are displayed in the UI.
*(Integration test — requires Cipher's Trial scene loaded. `nodes_completed` excludes
the Trial node currently being entered — see Formulas section definition.)*

**[I] AC-VS-10** — GIVEN a Cipher's Trial option whose cost would reduce Fayde's HP
to 0 or below, WHEN the player attempts to select that option, THEN the selection is
rejected and no tradeoff is applied to Fayde's state.

**[V] AC-VS-11** — GIVEN a disabled Cipher's Trial option (cost too high), WHEN it is
displayed, THEN it appears visually distinct from selectable options using a non-color-only
affordance (e.g., icon, pattern, or text label — not color alone).
*(Advisory — screenshot evidence required; Visual/Feel gate; accessibility requirement.)*

**[I] AC-VS-12** — GIVEN Fayde has 1 HP, WHEN the player pays the Cipher's Trial skip
cost, THEN the active state becomes `PATH_SELECTION` and no `run_ended` signal is
emitted. *(HP floor behavior is a separate AC owned by the Health & Damage GDD.)*

**[I] AC-VS-13** — GIVEN the player is in `CIPHERS_TRIAL` and attempts to exit without
selecting an option or paying the skip cost, WHEN exit is attempted, THEN exit is
blocked and the player remains in `CIPHERS_TRIAL`.

**[U] AC-VS-14** — GIVEN the game is in `PATH_SELECTION`, WHEN the path map is queried
for displayable nodes, THEN only nodes directly connected to the current room are
returned — nodes two or more steps ahead are not included in the result set.
*(Tests Core Rule 5. If PathMap requires a scene fixture rather than a pure data
structure, retag [I] when implementing.)*

**[I] AC-VS-15** — GIVEN the active state is `ROOM_TRANSITION`, WHEN
`_request_transition(any_state)` is called, THEN the state remains `ROOM_TRANSITION`
and the request is rejected.

**[I] AC-VS-16** — GIVEN a Room Transition is initiated with payload `node_type = SHOP`,
WHEN the transition completes, THEN the active state becomes `SHOP_PHASE` — not any
other state.

**[V] AC-VS-17** — GIVEN the `PATH_SELECTION` map is displayed, WHEN a Cipher's Trial
node is present, THEN a non-color-only affordance indicating committed-interaction is
visible without hover, focus, or selection required.
*(Core Rule 6 information requirement — pre-entry consent pattern. Specific visual
design is owned by the VS UX spec for Path Selection, but this AC verifies the
requirement is met before implementation proceeds.)*

## Open Questions

[None — all design decisions resolved as of 2026-05-22 post-design-review revision.]
