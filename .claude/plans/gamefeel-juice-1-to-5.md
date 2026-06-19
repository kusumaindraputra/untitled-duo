# Game Feel & Juice — Items 1–5 Implementation Plan

## Architecture Philosophy

All 5 items follow the **ADR-0003 signal-driven pattern**: systems react to signals
with local VFX, no new Autoloads needed. Each VFX is owned by the system closest
to the event it visualizes. Procedural `_draw()` over GPUParticles2D where possible
(follows SpellVFX._HitVFX precedent — zero node overhead, auto-cleanup).

---

## 1. Enemy Death VFX — Color Bloom

**File:** `src/gameplay/enemy_instance.gd`
**Hook:** `_on_enemy_killed(instance_id, type_id, prana_affiliation)` — signal carries
`prana_affiliation` parameter, no need to query registry.

**Implementation:**
- When `_on_enemy_killed` fires, before the death fallback timer returns:
  - Spawn a child `Node2D` (`_DeathBurst`) that draws an expanding ring + outward dots
  - Color: map `prana_affiliation` DamageClass to PranaType.color via PranaCatalog
  - Duration: 0.35s (procedural draw, auto queue_free)
- Pattern: identical to SpellVFX._HitVFX inner class — `_ready()` captures start time,
  `_process()` checks expiry, `_draw()` renders expanding circle + 6 radial dots
- No particles, no pool — pure GDScript proc-draw, auto-cleanup

**Visual spec:**
- Expanding ring: radius 10→60px, alpha 1→0, line width 3px
- 6 outward dots: along 60° rays, move 5→40px from center, alpha 1→0

---

## 2. Enemy Spawn VFX — Scale Tween

**File:** `src/systems/wave_manager.gd`
**Hook:** Inside `_spawn_wave()`, after `enemy.init(type_id)` and before incrementing
`spawn_idx`.

**Implementation:**
- After `enemy.init(type_id)`, set `enemy.scale = Vector2.ZERO`
- Create Tween: `scale` 0→1 over 0.18s with `Tween.TRANS_BACK` + `Tween.EASE_OUT`
  (BACK gives a slight overshoot → settle, feels "pop-in" impactful)
- Staggered: optional — each enemy can start 30ms later via spawn_idx * 0.03 offset

**Test:** Integration test verifies enemies spawn with scale 0 then reach 1 after tween.

---

## 3. Projectile VFX — Trail + Glow + Wall Impact

**File:** `src/gameplay/projectile.gd`

**Changes:**

### 3a. Trail in `_draw()`
- Replace current `draw_circle(Vector2.ZERO, 4.0, ...)` with:
  - Outer glow circle: radius 10, alpha 0.15, color cyan
  - Core circle: radius 5, alpha 0.9, color white-cyan
  - Trail line: draw from current position backward along `-_direction * trail_len`
    where trail_len starts at 0, grows to 30 over first 0.15s
  - Track `_alive_time` in `_physics_process`

### 3b. Wall collision for impact
- Add `collision_mask |= 1` (wall layer bit 0)
- Handle `body_entered` for non-player bodies: spawn impact burst then queue_free
- Simple impact: scale jump to 2x then shrink to 0 over 0.12s (quick flash)
- OR: spawn a one-shot GPUParticles2D child, wait 0.2s, queue_free

### 3c. Despawn fade
- When approaching MAX_RANGE (last 50px), trail fades alpha 0.9→0

---

## 4. Room Clear Warm Wash — Gold Overlay

**File:** `src/scenes/debug_game_loop.gd`
**Signal:** `GameStateManager.wave_ended`

**Implementation:**
- In `_ready()`, connect `GameStateManager.wave_ended` to a new handler
- Handler creates a `ColorRect` overlay inside `$CanvasLayer`:
  - Color: gold warm `Color(1.0, 0.85, 0.4, 0.0)`
  - Anchor full-rect
  - Mouse filter: IGNORE
- Tween sequence:
  1. Flash in: `color.a` 0→0.18 over 0.15s (EASE_OUT)
  2. Hold: 0.6s interval
  3. Fade out: `color.a` 0.18→0 over 0.5s (EASE_IN)
  4. `queue_free()` at end

This matches Art Bible spec: *"Brief warm shift... Soft gold wash, 1-2 seconds."*

---

## 5. Dash VFX Trail — Dust Burst + Afterimage Ghosts

**File:** `src/gameplay/player_controller.gd`
**Hook:** Inside `_physics_process` dash trigger (around line 160-172)

**Implementation:**

### 5a. Dust burst at dash start
- When dash activates, spawn 2 temporary Node2D children that draw dust puffs:
  - Each is a `_DashDust` inner class (same pattern as SpellVFX._HitVFX)
  - Draws 4-5 small circles expanding outward + upward
  - Duration: 0.3s, alpha fade
  - Two instances at slightly different positions (±15px offset)
  - Position at Fayde's feet

### 5b. Afterimage ghosts
- On dash start, capture current sprite frame from `_iso_char`
- Create 2-3 ghost `Sprite2D` nodes at Fayde's position:
  - Same texture as current IsoCharacter frame
  - Alpha: [0.4, 0.2, 0.1]
  - Scale: same as sprite_scale
  - Z-index: below Fayde (z_index - 1)
  - Tween alpha to 0 over 0.3s → queue_free
  - Slightly offset each ghost backward (opposite dash direction) by 15px each
- Ghosts are top_level + world-positioned so they don't move with Fayde

### 5c. SFX already exists
- `sfx_fayde_dash` already fires via `audio_system.play_event(&"sfx_fayde_dash")`
- No change needed

---

## Test Plan

| Item | Test Type | File | What It Covers |
|------|-----------|------|----------------|
| 1. Death VFX | Unit | `tests/unit/gamefeel/enemy_death_vfx_test.gd` | DeathBurst spawns, draws, cleans up; color maps correctly per affiliation |
| 2. Spawn VFX | Unit | `tests/unit/gamefeel/enemy_spawn_vfx_test.gd` | Scale starts at 0, tween created |
| 3. Projectile | Unit | `tests/unit/gamefeel/projectile_vfx_test.gd` | Trail draws, wall impact handles, despawn fade |
| 4. Room Clear | Integration | Manual (visual) + verify overlay tween lifecycle |
| 5. Dash VFX | Unit | `tests/unit/gamefeel/dash_vfx_test.gd` | Dust nodes spawned, ghost sprites created, cleanup after tween |

**GdUnit4 conventions:** `before_test()`/`after_test()` hooks. `node.free()` for orphan nodes (never `queue_free()`). Test names: `test_[action]_[expected_result]`.

---

## File Changes Summary

| # | File | Change Type |
|---|------|-------------|
| 1 | `src/gameplay/enemy_instance.gd` | Add `_spawn_death_burst()` + `_DeathBurst` inner class |
| 2 | `src/systems/wave_manager.gd` | Add scale tween in `_spawn_wave()` after `enemy.init()` |
| 3 | `src/gameplay/projectile.gd` | Rewrite `_draw()`, add wall collision, add trail tracking |
| 4 | `src/scenes/debug_game_loop.gd` | Add `wave_ended` handler + warm wash overlay |
| 5 | `src/gameplay/player_controller.gd` | Add `_DashDust` inner class + ghost sprite nodes |
| — | `tests/unit/gamefeel/` (new dir) | 4 unit test files |

## Risk / Edge Cases

- **Death VFX cleanup:** If scene reloads mid-death-burst, the Node2D child is freed
  with the parent — no orphan risk.
- **Spawn tween + status effects:** Scale tween uses `create_tween()` which is
  `PROCESS_MODE_PAUSABLE` by default — freeze/stun won't interrupt the tween.
- **Dash ghost with missing sprite:** Guard against null `_iso_char` or no animation.
- **Projectile wall collision race:** `body_entered` may fire same frame as `queue_free`
  at MAX_RANGE — use `is_instance_valid` guard.
