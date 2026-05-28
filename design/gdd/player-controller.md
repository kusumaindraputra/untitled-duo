# Player Controller

> **Status**: In Revision (post-design-review round 2 — pending re-review)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-28
> **Implements Pillar**: Pillar 3 (Chaos Has Consequences) — movement and positioning determine which Prana hits land and which enemy hits are taken

## Overview

Player Controller owns every aspect of Fayde's movement and collision in the arena. It translates keyboard and gamepad input into movement velocity, applies physics via `CharacterBody2D.move_and_slide()`, and manages Fayde's dash ability as a short-range burst with a cooldown. It is state-driven: movement is enabled exclusively in `COMBAT_PHASE` (on `combat_started`, both regular and boss waves), disabled during `PREPARATION_PHASE` (on `preparation_started`), and suspended in `PAUSED` — all driven by signals from Game State & Scene Flow. No other system enables or disables Fayde's movement.

At MVP scope, Player Controller covers three behaviors: **movement** (8-directional screen-space input, configurable speed), **dash** (short-range directional burst with cooldown), and **collision response** (Fayde cannot walk through arena walls or obstacles; enemy contact is detected and passed to Health & Damage as `DamageSource.CONTACT`). Spell casting is not owned here — Spell Casting & Effects (#3) reads Player Controller's position as cast origin, but the trigger is entirely owned by that system.

**ADR-0001 constraint:** Movement is screen-space — WASD maps to up/down/left/right relative to the screen. Isometric projection is visual only; all gameplay logic (collision, position, spell origin) operates in 2D cartesian space. See `docs/architecture/adr-0001-isometric-view.md`.

## Player Fantasy

Fayde's movement is a statement of intent. Every step toward or away from an enemy is a commitment — the arena is not empty space to fill, it is a problem to read before moving into it. The fantasy is **the satisfaction of correct positioning**: setting up so the Prana pre-arranged fires from exactly the angle that catches the Charger mid-approach, then holding that ground through the wave because you read it right.

Dash is the punctuation mark of that commitment — a short, directional burst that passes through enemies with brief invincibility, reserved for the moment when the read was wrong. Fayde slides *through* the oncoming Charger and lands behind it. Not a get-out-of-jail card that trivializes positioning (its cooldown ensures this), but a single corrective action per engagement that rewards timing. A player who dashes on instinct at the wrong moment will have nothing left when they need it.

The paired fantasy: the run where you barely used the dash at all, because the grid arrangement and the positioning were that well-read. And the run where you burned it to survive a Cluster swarm, then had to finish the wave on foot with two enemies still up. Both are correct expressions of Pillar 3 — *Chaos Has Consequences*.

**Reference feel**: the decisive footing of Dead Cells at low health — when every move is chosen, not reflexive — compressed into the short combat windows of a roguelike wave. Not the frantic APM of a twin-stick shooter. The read comes first. *(Note: snap-to-stop delivers precision and intent, not momentum-weight. The fantasy is deliberate placement, not physical inertia.)*

## Detailed Design

### Core Rules

1. **Node type**: Fayde is implemented as a `CharacterBody2D` with `process_mode = PROCESS_MODE_PAUSABLE`. Movement is computed and applied in `_physics_process(delta)` using `move_and_slide()`. All position and velocity state lives on this node.

2. **State-driven enable/disable**: Player Controller has three operative states — `ENABLED`, `DISABLED`, and `DASHING` (see States and Transitions). Movement and dash input are only processed when in `ENABLED` or `DASHING`. On `game_paused`, `_physics_process` is automatically suspended by `PROCESS_MODE_PAUSABLE` — no additional pause logic is required.

   Signal connections made at `_ready()`:
   - `GameStateManager.combat_started` → `_on_combat_started()` — sets state to `ENABLED`
   - `GameStateManager.preparation_started` → `_on_preparation_started()` — sets state to `DISABLED`, zeroes velocity, **and clears `_is_invincible`** (handles mid-dash cancellation; see Edge Case #2)

   **GameStateManager is a Godot autoload singleton.** Signal connections in `_ready()` are safe because autoloads are always available before scene nodes. Do not implement GameStateManager as a scene-tree node — doing so introduces ready-order fragility.

   **Belt-and-suspenders DISABLED guard**: `_physics_process` has the following as its first statement: `if _controller_state == DISABLED: velocity = Vector2.ZERO; return`. This ensures velocity is always zeroed even if `preparation_started` fires via a deferred call before `_physics_process` re-evaluates.

3. **Movement — 8-directional screen-space**: Input is read via `Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")` each physics frame. This returns a `Vector2` in `[-1, 1]` range, normalized when diagonal. The result is screen-space: WASD maps to the four screen axes; no diagonal remapping for isometric (per ADR-0001 — isometric is visual only).

   **Friction-based deceleration (delta-corrected)**: Velocity is updated each frame using framerate-independent weights computed from `delta`:
   - `_move_factor = 1.0 - pow(1.0 - MOVE_ACCELERATION, delta * 60.0)`
   - `_friction_factor = 1.0 - pow(1.0 - MOVE_FRICTION, delta * 60.0)`
   - When `input_dir.length() > 0`: `velocity = velocity.lerp(input_dir.normalized() * MOVE_SPEED, _move_factor)`
   - When `input_dir.length() == 0`: `velocity = velocity.lerp(Vector2.ZERO, _friction_factor)`

   *(This is the canonical zero-input guard: `input_dir.length() > 0`. Formula 1 uses the same condition. "Input held" and "input released" are shorthand for this check — do not substitute an `is_action_pressed` check.)*
   - **Snap-to-stop**: After applying friction, if no input and `velocity.length() < VELOCITY_SNAP_THRESHOLD`, set `velocity = Vector2.ZERO` immediately. Ensures predictable stop positions — the player lands exactly where they intend, delivering the "every step is a commitment" feel.
   - `MOVE_ACCELERATION`, `MOVE_FRICTION`, and `VELOCITY_SNAP_THRESHOLD` are tuning knobs (see Tuning Knobs). With defaults, stop time is ~0.17s.

4. **Dash**: On `dash` action pressed (keyboard: `Shift`; gamepad: `B`/circle), if dash cooldown has expired and the controller is `ENABLED`:
   - Capture the current 8-directional locked direction (snap current input or facing direction to the nearest cardinal or diagonal using 45° sector boundaries)
   - Enter `DASHING` state for `DASH_DURATION` (default 0.15s)
   - During dash: override velocity to `dash_dir.normalized() * DASH_SPEED`; grant i-frames (`_is_invincible = true`)
   - On dash end: return to `ENABLED`; start `DASH_COOLDOWN` timer; clear i-frames
   - If no movement input at dash moment: dash in last-moved direction. If no last direction: dash in facing direction (default: right)

   **8-directional lock (screen-space)**: Snap the input vector to the nearest of 8 screen-space directions before computing `dash_dir`. The 8 snap directions are aligned with WASD (±X, ±Y, and diagonals) — not isometric world-space axes (consistent with ADR-0001). A player pressing diagonally toward a visually "forward" enemy in isometric view dashes to the nearest screen-space diagonal, which may not match visual intent. This must be communicated on the player's first dash attempt via a Memo hint.

   **Snap algorithm (canonical implementation):**
   ```
   var snap_angle := round(atan2(input_dir.y, input_dir.x) / (PI / 4.0)) * (PI / 4.0)
   var dash_dir := Vector2(cos(snap_angle), sin(snap_angle))
   ```
   GDScript's `round()` resolves ties at 22.5° sector boundaries away from zero (e.g., exact 22.5° snaps to 45°). This boundary occurs only when input is bit-exact at the midpoint — acceptable either way. Do not substitute a dot-product argmax approach; the atan2 method is the canonical spec and both approaches agree at all non-boundary inputs.

   `_last_facing_dir` is always stored **post-snap** (one of the 8 canonical unit directions), so no re-snap is needed when used as the no-input fallback.

   **I-frames during dash**: For the duration of `DASH_DURATION`, Health & Damage's `apply_damage(source: CONTACT)` calls are blocked by a flag on Player Controller (`_is_invincible`). Health & Damage **queries** `PlayerController.is_invincible() -> bool` as the first check in its `apply_damage` pipeline — before the dead-target guard — and returns immediately with no damage applied and no signal emitted if `true`. *(Resolution of Open Question #1: query pattern adopted. Health & Damage GDD updated in round-2 review — step 1a added to `apply_damage` pipeline and Player Controller listed in H&D Dependencies.)*

   The dash i-frame window (0.15s) is distinct from Health & Damage's post-hit i-frame window (0.5s, contact-triggered). Both protect Fayde from CONTACT damage; `is_invincible()` returning `true` causes H&D to skip the call regardless of which source triggered it.

5. **Collision**: Fayde cannot pass through arena walls or static obstacles. `move_and_slide()` handles this automatically via physics layers. Enemy bodies occupy a separate collision layer — Fayde does not physically block enemies spatially; enemy contact damage is triggered by Enemy AI's hit detection, not by Player Controller collision.

6. **Footstep audio**: When `get_controller_state() == ENABLED` and `velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD`, Player Controller fires the next footstep variant via a float accumulator timer (every `FOOTSTEP_INTERVAL_SEC`, default 0.38s — ~2.6 steps/sec). The accumulator resets to zero when velocity drops below `FOOTSTEP_VELOCITY_THRESHOLD` (timer restarts on re-entry, preventing an immediate fire after a brief stop).

   **Footstep suspension during DASHING**: The timer callback must guard on state: `if _controller_state != ENABLED: return` (before the velocity check and before any `play_event()` call). This guard is required because `DASH_SPEED` (400 px/sec default) far exceeds `FOOTSTEP_VELOCITY_THRESHOLD` (10 px/sec) — the velocity check alone does NOT suppress footsteps during a dash. The accumulator continues incrementing during DASHING but does not fire. On return to ENABLED, if velocity > threshold, the next footstep fires after the remaining interval.

   **Footstep variant shuffle-bag**: Three events are registered in `AudioEventRegistry`: `sfx_fayde_footstep_a`, `sfx_fayde_footstep_b`, `sfx_fayde_footstep_c`. Player Controller maintains `_footstep_bag: Array[StringName]`. On each footstep trigger: pop from the bag and call `audio_system.play_event(popped_variant)`. When the bag empties: refill with `[&"sfx_fayde_footstep_a", &"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"]`, shuffle, then if the new first element equals the last-played variant, swap it with a random other position (anti-consecutive-repeat guarantee).

   Dash calls `audio_system.play_event(&"sfx_fayde_dash")` once at dash initiation. Player Controller is the **authoritative and exclusive caller** for `sfx_fayde_dash` — see Visual/Audio Requirements for priority and ownership note.

   **Timer implementation**: Both the footstep accumulator and the dash cooldown accumulator use the **float accumulator pattern** tracked inside `_physics_process(delta)` — the accumulator increments by `delta` each physics frame. Do **NOT** use `SceneTree.create_timer()` (counts wall-clock time, does not pause with the node) or `Timer` nodes. The float accumulator automatically pauses with `PROCESS_MODE_PAUSABLE` because `_physics_process` is not called on paused nodes. For unit testing, drive timers by calling `_physics_process(1.0 / 60.0)` repeatedly until the target interval accumulates.

7. **No movement during PREPARATION_PHASE**: On `preparation_started`, velocity is zeroed immediately. Fayde cannot move, dash, or change facing while the Prana Grid is active.

---

### States and Transitions

| State | Condition | Movement input | Dash input | I-frames |
|-------|-----------|---------------|------------|---------|
| `DISABLED` | PREPARATION_PHASE or any non-combat state | Ignored | Ignored | No |
| `ENABLED` | COMBAT_PHASE, dash not active | Processed | Available (if cooled) | No |
| `DASHING` | COMBAT_PHASE, dash active | Ignored (velocity overridden) | Ignored (cannot chain) | **Yes** |

| From | To | Trigger |
|------|----|---------|
| `DISABLED` | `ENABLED` | `combat_started` signal received (both `is_boss: false` and `is_boss: true`) |
| `ENABLED` | `DISABLED` | `preparation_started` signal received; velocity zeroed immediately |
| `ENABLED` | `DASHING` | Dash action pressed + cooldown expired |
| `DASHING` | `ENABLED` | `DASH_DURATION` timer expires; `DASH_COOLDOWN` timer begins |
| `DASHING` | `DISABLED` | `preparation_started` signal received mid-dash; dash cancelled — velocity zeroed, `_is_invincible` cleared, **`DASH_COOLDOWN` timer begins** (cancelled dash counts as used; see Edge Case #2) |

**Re-entry on boss combat**: `combat_started(is_boss: true)` also transitions `DISABLED → ENABLED` — Fayde enters boss combat from the final Preparation phase's disabled state.

---

### Interactions with Other Systems

| System | Interaction | Direction |
|--------|-------------|-----------|
| **Game State & Scene Flow** | Listens to `combat_started`, `preparation_started` to enable/disable movement; `PROCESS_MODE_PAUSABLE` handles pause automatically | Game State → Player Controller |
| **Health & Damage** | Exposes `is_invincible() -> bool` — queried at step 1a of `apply_damage` to block CONTACT damage during all i-frame windows | Player Controller → Health & Damage |
| **Spell Casting & Effects (#3)** | Exposes `get_world_position() -> Vector2` (wraps `global_position`) and `get_facing_direction() -> Vector2` as the cast origin and direction for Prana spells | Player Controller → Spell Casting |
| **Enemy AI (#8)** | Enemy AI reads `PlayerController.global_position` to navigate toward Fayde; Player Controller does not import Enemy AI | Enemy AI reads Player Controller (one-way) |
| **Audio System** | Calls `audio_system.play_event(sfx_fayde_footstep_variant)` (one of `sfx_fayde_footstep_a/b/c` via shuffle-bag) on movement timer, and `audio_system.play_event(&"sfx_fayde_dash")` on dash initiation (via injected reference — see Dependencies). **Player Controller is the authoritative and exclusive caller for `sfx_fayde_dash`** — the Audio System GDD's Interactions table incorrectly lists Game Feel/Juice (#30) for "dash cues"; correct this when authoring the Game Feel GDD. | Player Controller → Audio System |

## Formulas

> Player Controller formulas govern movement feel, not gameplay balance. No formula here affects damage, HP, or run outcomes.

### Formula 1: Movement Velocity (Friction-Based, Delta-Corrected)

Each `_physics_process(delta)` frame, compute framerate-independent weights from `delta`:

`_move_factor = 1.0 - pow(1.0 - MOVE_ACCELERATION, delta * 60.0)`
`_friction_factor = 1.0 - pow(1.0 - MOVE_FRICTION, delta * 60.0)`

**When input is held (`input_dir.length() > 0`):**
`velocity = lerp(velocity, input_dir.normalized() * MOVE_SPEED, _move_factor)`

**When no input (`input_dir == Vector2.ZERO`):**
`velocity = lerp(velocity, Vector2.ZERO, _friction_factor)`
If `velocity.length() < VELOCITY_SNAP_THRESHOLD`: `velocity = Vector2.ZERO`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current velocity | `velocity` | Vector2 | magnitude 0 – `MOVE_SPEED` | Fayde's current movement vector (px/sec) |
| Input direction | `input_dir` | Vector2 | normalized magnitude 0 or 1 | WASD/gamepad input this frame |
| Move speed | `MOVE_SPEED` | float | 80–200 px/sec | Maximum movement speed (tuning knob) |
| Acceleration factor | `MOVE_ACCELERATION` | float | 0.1–1.0 (base weight; delta-corrected at runtime) | How fast velocity reaches MOVE_SPEED; 1.0 = instant |
| Friction factor | `MOVE_FRICTION` | float | 0.1–1.0 (base weight; delta-corrected at runtime) | How fast velocity decays toward zero; 1.0 = instant stop |
| Snap threshold | `VELOCITY_SNAP_THRESHOLD` | float | 4–20 px/sec | Below this velocity with no input, velocity zeroes immediately |

**Output range:** velocity magnitude 0.0 – `MOVE_SPEED` px/sec

**Stop time (corrected):** With `MOVE_FRICTION = 0.25`, `VELOCITY_SNAP_THRESHOLD = 8 px/sec`, starting from `MOVE_SPEED = 120 px/sec` at 60 fps:
- Velocity halves every ~**2.4 frames** (per-frame factor 0.75 at 60 fps)
- Snap-to-stop triggers when velocity < 8 px/sec: at frame **10** (~0.17s)
- The delta-corrected formula maintains consistent feel across framerates (60, 90, 120 fps); the snap threshold creates a pixel-predictable stop position regardless of remaining drift

**Example (deceleration from MOVE_SPEED = 120 px/sec, MOVE_FRICTION = 0.25, VELOCITY_SNAP_THRESHOLD = 8, 60 fps):**
- Frame 0: 120 → Frame 1: 90 → Frame 2: 67.5 → Frame 3: 50.6 → Frame 4: ≈38 → Frame 8: ≈12 → Frame 10: 6.8 → **snap to 0**

---

### Formula 2: Dash Distance

`DASH_DISTANCE = DASH_SPEED × DASH_DURATION`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Dash speed | `DASH_SPEED` | float | 200–600 px/sec | Velocity applied during dash override |
| Dash duration | `DASH_DURATION` | float (sec) | 0.08–0.25s | Duration of the dash burst |
| Dash distance | `DASH_DISTANCE` | float (px) | 16–150 px | Total spatial displacement during dash |

**Output range:** 16 px (minimum: 200 × 0.08) to 150 px (maximum: 600 × 0.25)

**Default:** `DASH_SPEED = 400`, `DASH_DURATION = 0.15s` → `DASH_DISTANCE = 60 px` — approximately 1 tile width at the 64×32 isometric tile size. *(Provisional: the claim that 60px "passes fully through a standard enemy" is unvalidated — enemy collision box dimensions are not specified until the Enemy AI GDD. Confirm this value against Charger hitbox dimensions before First Playable.)*

**Tunneling note:** The physics tunneling threshold is framerate-dependent. At 60 fps, per-frame displacement at DASH_SPEED = 600 px/sec is 10 px — below typical wall thickness. At 30 fps, per-frame displacement doubles; tunneling risk begins near DASH_SPEED = 400 px/sec (the default). The stated safe range assumes the 60 fps target holds. If tunneling is observed: reduce `DASH_SPEED` or enable continuous collision detection on the `CharacterBody2D` node.

---

### Formula 3: Footstep Fire Rate

`steps_per_second = 1.0 / FOOTSTEP_INTERVAL_SEC`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Footstep interval | `FOOTSTEP_INTERVAL_SEC` | float (sec) | 0.25–0.6s | Time between `play_event(&"sfx_fayde_footstep")` calls |
| Steps per second | — | float | 1.67–4.0 | Resulting audio event frequency when walking |

**Default:** 0.38s → 2.63 steps/second. Not tied to animation frame count at MVP.

**Guard:** `FOOTSTEP_INTERVAL_SEC` must be clamped above 0.0 in the setter — a value of 0.0 produces division by zero and infinite timer fire rate.

## Edge Cases

1. **If `combat_started` fires while Fayde is mid-dash:** Dash completes normally — `DASHING` is already a sub-state of combat-active. No special handling needed.

2. **If `preparation_started` fires while Fayde is mid-dash:** Cancel the dash immediately — velocity zeroed, `_is_invincible` cleared. **Start the `DASH_COOLDOWN` timer from this point** — a cancelled dash counts as a used dash (the same cooldown applies whether the dash completed or was interrupted). State transitions to `DISABLED`. This is handled in `_on_preparation_started()`, which explicitly clears `_is_invincible` and starts the cooldown accumulator in the same call as zeroing velocity.

3. **If dash is triggered with no movement input and no stored last-moved direction:** Dash fires to the right (default facing direction). Occurs at combat start before Fayde has moved. Visually jarring but functionally safe — cannot damage Fayde or break game state.

4. **If `MOVE_FRICTION = 1.0`:** The delta-corrected factor equals 1.0 — velocity zeroes in one frame via lerp before the snap check. Valid extreme value; the formula handles it correctly.

5. **If `MOVE_ACCELERATION = 1.0`:** Velocity reaches `MOVE_SPEED` in one frame — instant acceleration. Combined with `MOVE_FRICTION = 1.0`, produces instant-start/instant-stop movement with no weight.

6. **If `DASH_SPEED` is tuned so high that `move_and_slide()` tunnels through a wall:** The tunneling threshold is framerate-dependent. At 60 fps, per-frame displacement at DASH_SPEED = 600 px/sec is 10 px — below typical wall thickness. At 30 fps, per-frame displacement doubles; tunneling risk begins near DASH_SPEED = 400 px/sec (the default). The safe-range maximum (600 px/sec) assumes the 60 fps target holds. If tunneling is observed: reduce `DASH_SPEED` or enable continuous collision detection on the `CharacterBody2D` node.

7. **If the player holds the dash button:** Dash fires once per press (`is_action_just_pressed`) — holding does not repeat. The cooldown timer prevents rapid re-press regardless.

8. **If dash cooldown expires during `DISABLED` state:** The timer clears normally. Dash is available immediately when the next `combat_started` fires. No queued dash — the player must press again to initiate.

9. **If velocity is non-zero when `preparation_started` fires** (player was running): `_on_preparation_started()` zeroes velocity directly. If the signal fires within the current `_physics_process` invocation, `move_and_slide()` has already run — no additional movement occurs this frame. If the signal fires as a deferred call (after this frame's `_physics_process`), the belt-and-suspenders DISABLED guard at the top of `_physics_process` (`if _controller_state == DISABLED: velocity = Vector2.ZERO; return`) zeroes velocity on the very next physics frame. At 60 fps, at most 16ms of drift — imperceptible. The earlier claim of "one frame of residual motion" was imprecise; the correct mechanism is the DISABLED guard, not engine residual.

10. **If `audio_system` is not initialized when a footstep event fires:** `play_event()` logs `push_error()` and returns without playing. No crash. Footstep timer continues normally.

## Dependencies

### Systems This System Depends On

| System | What's needed | Dependency type | Scope |
|--------|--------------|----------------|-------|
| **Game State & Scene Flow (#27)** | `combat_started`, `preparation_started` signals to enable/disable movement | Hard | MVP |
| **Audio System (#29)** | `play_event()` API for footstep and dash SFX | Soft (graceful no-op if Audio System absent) | MVP |

Player Controller has no runtime dependencies on Prana Data, Health & Damage, or Enemy AI — it exposes an interface those systems read, but does not import them.

**AudioSystem injection**: Player Controller declares `@export var audio_system: AudioSystem`. In `_ready()`, assign the production default: `audio_system = AudioSystem` (the autoload singleton name — substitute your project's actual autoload name). The `@export` annotation allows a test mock to override this default by assigning directly in GUT's `before_each()` before calling `_ready()`, or by setting the export slot in a dedicated test scene. Do not call the AudioSystem autoload by global name anywhere inside Player Controller other than this one `_ready()` assignment — the rest of the code uses the `audio_system` reference exclusively. This ensures the DI seam is always active for ACs PC-15, PC-16, and PC-17.

### Systems That Depend on This System

| System | What it needs | Bidirectional contract |
|--------|--------------|----------------------|
| **Health & Damage (#6)** | `is_invincible() -> bool` — queried at step 1a of `apply_damage` before the dead-target guard | Health & Damage GDD must add this query step and list Player Controller as a dependency |
| **Spell Casting & Effects (#3)** | `get_world_position() -> Vector2`, `get_facing_direction() -> Vector2` — cast origin and direction for Prana spells | Spell Casting GDD must declare Player Controller as a dependency |
| **Enemy AI (#8)** | `global_position` (built-in — no custom getter needed) as pathfinding target | Enemy AI GDD must declare Player Controller as a dependency |
| **Wave / Encounter System (#12)** | Fayde position for spawn placement (avoids spawning on top of Fayde) | Wave/Encounter GDD must declare Player Controller as a dependency |

### Interface Constraints for Downstream GDDs

1. Signal names from Game State & Scene Flow must be referenced exactly — do not redefine them.
2. **Health & Damage GDD updated** (round-2 review, 2026-05-28): step 1a added to `apply_damage` pipeline and Player Controller added to H&D Dependencies table.
3. Player Controller does not emit position-change signals — systems that need position poll `global_position` directly each frame.

## Tuning Knobs

| Knob | Default | Safe Range | What it affects | What breaks if wrong |
|------|---------|------------|-----------------|----------------------|
| `MOVE_SPEED` | 120 px/sec | 80–200 px/sec | Fayde's maximum movement speed | Too low: can't escape enemy attacks; too high: arena feels small, positioning decisions become trivial |
| `MOVE_ACCELERATION` | 0.2 | 0.1–1.0 (base lerp weight/frame) | How fast velocity reaches `MOVE_SPEED` from standstill | Too low: sluggish, unresponsive; too high: instant acceleration, removes movement weight |
| `MOVE_FRICTION` | 0.25 | 0.1–1.0 (base lerp weight/frame) | How fast Fayde decelerates when input released | Too low: drifts past intended position; too high: rapid stop — tune together with VELOCITY_SNAP_THRESHOLD |
| `VELOCITY_SNAP_THRESHOLD` | 8 px/sec | 4–20 px/sec | Below this speed with no input, velocity zeroes immediately — ensures pixel-predictable stop position | Too low: perceivable drift before snap; too high: movement feels digital/stiff. Must stay below FOOTSTEP_VELOCITY_THRESHOLD (10 px/sec default) |
| `DASH_SPEED` | 400 px/sec | 200–600 px/sec | Velocity override during dash burst | Too low: dash barely outruns walking; too high: wall tunneling risk at 30 fps begins near the default 400 px/sec |
| `DASH_DURATION` | 0.15s | 0.08–0.25s | Dash burst duration AND i-frame window duration | Too short: insufficient travel distance; too long: i-frames exploitable for sustained invincibility |
| `DASH_COOLDOWN` | **2.0s** | 0.5–3.0s | Time before dash can be reused | Too short: dash trivializes positioning; too long: players forget the ability exists. Raised from 1.0s to create scarcity. *Target: 3–6 uses per typical wave (wave duration TBD by Wave/Encounter GDD — validate at First Playable).* |
| `FOOTSTEP_INTERVAL_SEC` | 0.38s | 0.25–0.6s | Time between footstep audio events while moving | Too short: footsteps clutter the mix; too long: movement sounds unconvincing. Must be > 0.0 (clamp in setter) |
| `FOOTSTEP_VELOCITY_THRESHOLD` | 10 px/sec | 5–30 px/sec | Minimum velocity required to fire footstep timer | Too low: footsteps fire during deceleration tail; too high: missed footsteps during slow movement |

**Interaction notes:**
- `DASH_DURATION` is simultaneously the i-frame window. If feel and i-frame duration need to diverge in playtesting, split into `DASH_DURATION` and `DASH_IFRAME_DURATION`.
- Maintain `DASH_SPEED / MOVE_SPEED ≥ 2.5` for dash to feel meaningfully faster than walking. Below this ratio, dash reads as a fast walk. **This constraint is not range-enforced in the tuning table** — if MOVE_SPEED is raised above 160 px/sec, DASH_SPEED minimum must be raised proportionally (e.g., MOVE_SPEED=200 requires DASH_SPEED ≥ 500).
- `VELOCITY_SNAP_THRESHOLD` must always be set below `FOOTSTEP_VELOCITY_THRESHOLD` (8 < 10 at defaults). **Setter guard required**: the `VELOCITY_SNAP_THRESHOLD` setter must validate `VELOCITY_SNAP_THRESHOLD < FOOTSTEP_VELOCITY_THRESHOLD` and call `push_error("VELOCITY_SNAP_THRESHOLD must be below FOOTSTEP_VELOCITY_THRESHOLD")` if violated. Without this guard, footstep events can fire after velocity has been zeroed by snap-to-stop.

## Visual/Audio Requirements

**Movement animation requirements:**
- Fayde requires a walk cycle animation covering all 8 movement directions (isometric dimetric: down, down-right, right, up-right, up, up-left, left, down-left). At 32–48px sprite height (ADR-0001), the walk cycle requires at minimum 4 frames per direction for legible limb movement.
- Idle animation: at minimum a 2-frame breathing or standing loop per facing direction. Fayde must not be fully static while waiting.
- Facing direction is retained from last movement input — Fayde does not snap to a default facing when velocity zeroes.

**Dash animation requirements:**
- Dash requires a visible motion blur, directional lean, or afterimage effect that distinguishes it from fast walking. A dash with no visual difference from running is a design failure — the i-frame window is invisible without it.
- Duration: the dash visual effect plays for `DASH_DURATION` (default 0.15s). Art pipeline must produce the effect within this window.
- Specific VFX technique (motion blur, trail, afterimage sprite) is deferred to Game Feel / Juice GDD (#30), which owns gameplay feedback VFX. This GDD owns only the requirement that a visible dash effect exists before ship.

**Audio requirements:**
- `sfx_fayde_footstep_a`, `sfx_fayde_footstep_b`, `sfx_fayde_footstep_c`: Three distinct variants registered separately in `AudioEventRegistry`. Player Controller owns the shuffle-bag selection (see Core Rule 6 — no consecutive repeat guarantee). Priority: LOW. Target level: −12 to −9 dBTP — textures the mix without competing with Prana cast sounds. Audio System must route these events through a dedicated non-pooled `AudioStreamPlayer2D` node (not the SFX pool) — pool-routing at 2.63 events/sec produces audible eviction pops under combat load. This is a hard requirement on the Audio System implementation; see Audio System Open Q3.
- `sfx_fayde_dash`: short burst (<0.3s), directional character. Priority: **HIGH** (raised from NORMAL). Registered in `AudioEventRegistry` as `bus = &"SFX"`. Minimum −6 dBTP (Prana SFX floor per Audio System GDD). HIGH priority is required because `sfx_fayde_dash` is the primary sensory confirmation that Fayde's i-frame window is active — silent drop at the critical dash moment is not an accepted tradeoff. **Player Controller is the authoritative and exclusive caller** — Game Feel / Juice (#30) owns the visual dash effect only. The Audio System GDD's Interactions table (which lists Game Feel/Juice as caller for "dash cues") must be corrected when that GDD is authored.

**All-ages constraint (hard):** All visual feedback for movement and dash must be appropriate for ages 7+. No violent aesthetics. The visual language should be energetic and expressive — Ghibli-like motion emphasis — not threatening.

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:player-controller` to produce per-asset visual descriptions and generation prompts from this section.

## UI Requirements

Player Controller has no player-facing UI of its own. HUD elements (HP bar, dash cooldown indicator) are owned by Combat HUD GDD (#22).

**Input action bindings** (defined in Project Settings → InputMap; must exist before implementation):

| Action | Keyboard default | Gamepad default |
|--------|-----------------|-----------------|
| `move_left` | `A` | Left stick left |
| `move_right` | `D` | Left stick right |
| `move_up` | `W` | Left stick up |
| `move_down` | `S` | Left stick down |
| `dash` | `Shift` | `B` / circle |

All actions must be rebindable. No hover-only input constraint applies to gameplay actions.

**Dash cooldown interface for HUD**: Player Controller exposes `get_dash_cooldown_remaining() -> float` (seconds until dash is ready; 0.0 if available). Combat HUD (#22) reads this to display a cooldown indicator.

**Keyboard navigation**: Player Controller's InputMap actions are gameplay-only and do not affect UI focus navigation. UI navigation uses separate InputMap actions owned by individual UI GDDs.

**Required class declaration**: The script must declare `class_name PlayerController`. Without this, GUT tests cannot reference `PlayerController.ENABLED` (or other enum values) without using raw integer literals, which violates the no-magic-numbers test standard.

**Testability interface**: The following methods must exist on Player Controller to enable GUT unit testing:
- `get_controller_state() -> int` — public getter for the internal `_controller_state` enum value (use `PlayerController.ENABLED` etc. in tests, not raw ints)
- `get_world_position() -> Vector2` — wraps `global_position`; used by Spell Casting and test assertions (valid only after node enters the scene tree)
- `get_facing_direction() -> Vector2` — returns `_last_facing_dir` (the post-snap canonical facing unit vector); used by AC-PC-19 and Spell Casting
- `get_dash_cooldown_remaining() -> float` — seconds until dash is ready; 0.0 if available; used by Combat HUD and AC-PC-18
- `_compute_dash_distance() -> float` — pure function: `return DASH_SPEED * DASH_DURATION`
- `_compute_steps_per_second() -> float` — pure function: `return 1.0 / FOOTSTEP_INTERVAL_SEC`

📌 **UX Flag — Player Controller**: Dash cooldown readout belongs to Combat HUD GDD (#22). Reference `PlayerController.get_dash_cooldown_remaining()` as the data source when authoring that GDD.

## Acceptance Criteria

*Test type: [U] = Unit test | [I] = Integration test | [M] = Manual QA | [V] = Visual review*

**Test harness requirements**: All [U] ACs require `Engine.physics_ticks_per_second = 60` set in the GUT test harness `before_all()`. Without pinned physics ticks, delta values are non-deterministic and all timing and velocity assertions are unreliable.

Both footstep and dash cooldown timers use the **float accumulator** pattern. Drive them in unit tests by calling `_physics_process(1.0 / 60.0)` repeatedly until the target interval accumulates (e.g., `ceil(FOOTSTEP_INTERVAL_SEC * 60)` calls to advance one footstep interval at 60 Hz).

ACs PC-15, PC-16, and PC-17 require `audio_system` set to a mock/spy object. Assign the mock directly to the `audio_system` property before calling `_ready()` (or immediately after instantiation if `_ready()` has already run). The mock must track whether `play_event()` was called and with which arguments.

### Movement

**[U] AC-PC-01** — GIVEN `get_controller_state() == ENABLED` and `move_right` is held, WHEN `_physics_process` runs for one frame, THEN `velocity.x > 0` and `velocity.length() ≤ MOVE_SPEED`.

**[U] AC-PC-02** — GIVEN `MOVE_FRICTION < 1.0` (precondition required — the formula is undefined at MOVE_FRICTION=1.0; at MOVE_FRICTION=1.0, snap fires in 1 frame by definition) AND Player Controller was moving at `MOVE_SPEED` and all input is released, WHEN `_physics_process` runs each frame at 60 physics ticks/sec, THEN `velocity` becomes `Vector2.ZERO` within `ceil(log(VELOCITY_SNAP_THRESHOLD / MOVE_SPEED) / log(1.0 - MOVE_FRICTION))` frames. *(Formula valid only at 60 physics ticks/sec. With defaults — MOVE_SPEED=120, MOVE_FRICTION=0.25, VELOCITY_SNAP_THRESHOLD=8 — bound is ≤ 10 frames. Verifies delta-corrected friction + snap-to-stop.)*

**[U] AC-PC-03** — GIVEN `get_controller_state() == DISABLED`, WHEN `move_right` is held and `_physics_process` runs, THEN `velocity == Vector2.ZERO` and `global_position` is unchanged.

**[I] AC-PC-04** — GIVEN the active game state is `PREPARATION_PHASE`, WHEN move input is injected for 0.5s, THEN `global_position` does not change. *(Requires Game State stub.)*

### Dash

**[U] AC-PC-05** — GIVEN `get_controller_state() == ENABLED` and dash cooldown expired, WHEN `dash` action is pressed, THEN: (a) `get_controller_state() == DASHING`; (b) `is_invincible() == true`; (c) `velocity.length()` is within 1% of `DASH_SPEED` — **assertion read on `velocity` immediately after the state enters DASHING, before `move_and_slide()` processes that frame** (test must use a wall-free unit test scene; `move_and_slide()` against a wall would deflect velocity and cause a false failure).

**[U] AC-PC-06** — GIVEN `get_controller_state() == DASHING`, WHEN `DASH_DURATION` elapses, THEN: (a) `get_controller_state() == ENABLED`; (b) `is_invincible() == false`; (c) `get_dash_cooldown_remaining() > 0`.

**[U] AC-PC-07** — GIVEN dash cooldown has NOT expired and Player Controller is moving at non-zero velocity, WHEN `dash` action is pressed, THEN `get_controller_state()` remains `ENABLED` and velocity is unchanged.

**[U] AC-PC-08** — GIVEN no movement input and no stored last-moved direction, WHEN dash is triggered, THEN velocity during dash points in the positive X direction (default right facing).

**[M] AC-PC-09** — GIVEN Fayde is dashing through an enemy that would deal CONTACT damage, WHEN the overlap occurs during `DASH_DURATION`, THEN no damage is applied and Fayde's HP is unchanged. *(Manual QA — requires Enemy AI present in scene.)*

### State Transitions

**[U] AC-PC-10** — GIVEN `get_controller_state() == ENABLED` and moving at `MOVE_SPEED`, WHEN `_on_preparation_started()` is called directly, THEN: (a) `get_controller_state() == DISABLED`; (b) `velocity == Vector2.ZERO` when read immediately after the call returns, before the next `_physics_process` invocation.

**[U] AC-PC-11** — GIVEN `get_controller_state() == DISABLED`, WHEN `_on_combat_started()` is called directly (parametrized: once with `is_boss = false`, once with `is_boss = true`), THEN `get_controller_state() == ENABLED` in both cases.

**[U] AC-PC-12** — GIVEN `get_controller_state() == DASHING`, WHEN `_on_preparation_started()` is called directly, THEN: (a) `get_controller_state() == DISABLED`; (b) `velocity == Vector2.ZERO` when read immediately after the call returns; (c) `is_invincible() == false` — **`_on_preparation_started()` explicitly clears `_is_invincible` as a direct statement in the signal handler** (Core Rule 2), not deferred to the timer-expiry path. The assertion is read immediately after the call returns, before any `_physics_process` invocation.

### Formulas

**[U] AC-PC-13** — GIVEN `DASH_SPEED = 400` and `DASH_DURATION = 0.15`, WHEN `_compute_dash_distance()` is called, THEN result is within ±1 px of 60.0.

**[U] AC-PC-14** — GIVEN `FOOTSTEP_INTERVAL_SEC = 0.38`, WHEN `_compute_steps_per_second()` is called, THEN result is within ±0.01 of 2.63.

### Audio

**[U] AC-PC-15** — GIVEN `get_controller_state() == ENABLED` and `velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD`, WHEN `FOOTSTEP_INTERVAL_SEC` elapses, THEN `audio_system.play_event()` is called exactly once with an argument matching one of `[&"sfx_fayde_footstep_a", &"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"]`. *(Requires AudioSystem mock set via `audio_system` property.)*

**[U] AC-PC-16** — GIVEN `velocity.length() < FOOTSTEP_VELOCITY_THRESHOLD`, WHEN `FOOTSTEP_INTERVAL_SEC` elapses, THEN `audio_system.play_event()` is NOT called with any footstep variant. *(Boundary: also verify with `velocity.length() == FOOTSTEP_VELOCITY_THRESHOLD` — footstep must NOT fire at exact threshold value, per the strict `>` condition in Core Rule 6.)*

**[U] AC-PC-17** — GIVEN `get_controller_state() == ENABLED` and dash cooldown has expired, WHEN the `dash` action is pressed, THEN `audio_system.play_event(&"sfx_fayde_dash")` is called exactly once.

**[U] AC-PC-20** — GIVEN `get_controller_state() == DASHING` (i.e., dash is active) and `velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD` (velocity override from DASH_SPEED satisfies the threshold), WHEN `FOOTSTEP_INTERVAL_SEC` elapses, THEN `audio_system.play_event()` is **NOT** called with any footstep variant. *(Verifies the state guard in the footstep timer callback — velocity check alone is insufficient because DASH_SPEED >> FOOTSTEP_VELOCITY_THRESHOLD.)*

**[U] AC-PC-21** — GIVEN `VELOCITY_SNAP_THRESHOLD` is assigned a value ≥ `FOOTSTEP_VELOCITY_THRESHOLD`, THEN a `push_error()` is emitted and the value is rejected (setter guard). *(Verifies the constraint setter guard from Tuning Knobs.)*

### Interface

**[U] AC-PC-18** — GIVEN `DASH_COOLDOWN = 2.0s` and dash was used 0.6s ago, WHEN `get_dash_cooldown_remaining()` is called, THEN result is within ±0.05s of 1.4s.

**[U] AC-PC-19** — GIVEN `get_controller_state() == ENABLED` and the last movement input was pure rightward `Vector2(1, 0)`, WHEN `get_facing_direction()` is called, THEN result is `Vector2(1, 0)` (normalized).

## Open Questions

1. ~~**I-frame query vs. signal pattern**~~ — **Resolved (round 1 review, H&D updated round 2)**: Health & Damage queries `PlayerController.is_invincible() -> bool` at step 1a of `apply_damage`, before the dead-target guard. H&D GDD updated 2026-05-28 with step 1a and Player Controller in Dependencies table. ✓ Closed.

2. **Footstep audio ownership** (resolves Audio System Open Q3): Resolved — Player Controller calls `audio_system.play_event()` for one of `sfx_fayde_footstep_a/b/c` via the shuffle-bag. Audio System must route these events through a dedicated non-pooled player (pool-routing at 2.63 events/sec produces eviction pops — see Visual/Audio Requirements). **Audio System GDD correction required**: the Audio System Interactions table incorrectly attributes "dash cues" to Game Feel/Juice (#30). Player Controller is the exclusive caller for `sfx_fayde_dash`. Update this when authoring the Game Feel GDD.

3. **Walk animation direction count**: Visual/Audio Requirements specify 8-direction walk cycles. If art production cost is prohibitive at First Playable, a 4-direction cycle (down, right, up, left) with mirroring for diagonal movement is a valid fallback. Resolve with the artist before sprite production begins.

4. **Dash visual effect ownership**: Dash VFX (motion blur, trail, afterimage) is deferred to Game Feel / Juice GDD (#30). If Game Feel is not in First Playable scope (currently Vertical Slice), a placeholder dash effect (simple color flash on Fayde's sprite) must be specified before First Playable ships — the i-frame window must be visually communicated. Resolve when First Playable scope is locked.

5. **Combat HUD dash cooldown display**: Player Controller exposes `get_dash_cooldown_remaining()`. Whether Combat HUD (#22) actually displays a dash cooldown indicator is a Combat HUD design decision. Flag this in the Combat HUD GDD when authored.
