# Status Effects

> **Status**: Approved (2026-06-16)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding), Pillar 3 (Chaos Has Consequences)

## Overview

Status Effects is the tick-timing authority for all persistent, Prana-triggered combat conditions in The Last Cipher. When Spell Casting & Effects lands a hit, it calls `apply_status(target, status_type, duration)` — Status Effects takes ownership from that moment: it tracks each active instance on each target, drives the tick timer via a float accumulator in `_process(delta)`, and calls back into Health & Damage (`apply_damage` for DoT ticks, `apply_heal` for HoT ticks) once per scheduled interval. Health & Damage owns the HP math; Status Effects owns the clock. At MVP scope, two effects are fully wired — **Burn** (Ashfire: damage-over-time, four ticks across 2.0s, 8% of base spell damage per tick) and **Freeze** (Deepfrost: movement root plus 50% speed reduction, 2.0s) — and three are implemented as structured stubs that accept `apply_status` calls, display their visual indicator, and hold their duration without executing tick logic: Blind (miss-chance reduction), Stun (brief attack-cancel), and Regenerate (heal-over-time on Fayde). All five conditional depth behaviours defined in Prana Data — Burn Contagion, Deepening Doubt, Lightning Follow-Through, Shatter, and Injury Bloom — are owned by this system and ship alongside their corresponding base effect: Contagion and Shatter at MVP with Burn and Freeze; the remaining three at Vertical Slice with their parent effects. From the player's perspective, Status Effects is the system that makes the Prana type in the centre slot matter past the initial hit: the Charger that charged through a Burn is still dying; the Cluster that walked into a Freeze root cannot reposition; the follow-up Deepfrost hit shatters the frozen enemy for an unexpected bonus — and the player realizes the arrangement they built ten seconds ago is still working.

## Player Fantasy

> *`creative-director` not consulted — Lean mode. Review manually before production.*

Status Effects is where Prana types prove they have *consequence*. The fantasy is **the arrangement that keeps working** — a spell Fayde fired eight seconds ago is still deciding the outcome of this wave. The Charger didn't die in the first hit, but it's burning. The Cluster rooted under a Freeze root can't scatter. The enemy the player staggered with Stormgold is frozen mid-lunge. The feeling isn't "I pressed the right button" — it's "I set this up."

The system delivers three distinct moments of satisfaction:

**1. The lingering threat** — A Burn tick fires on an enemy that has already moved out of Fayde's line of sight. The player didn't need to track it; the status did. The damage number floats up from behind a crate, and the player grins. This is the Ashfire fantasy: aggressive placement pays off after the moment of contact.

**2. The frozen opportunity** — A Charger that would have rushed and cancelled the next cast is instead rooted for two seconds under Deepfrost Freeze. That's a free cast window. The Deepfrost slow began as a defensive choice in the Preparation phase; in combat, it reads as offensive — the player bought time. This is the core Deepfrost fantasy: *patience imposed on a world that resists it.*

**3. The second-layer discovery** — The player hits a Frozen enemy with the next combo and sees a damage number that is noticeably larger than expected. No tooltip warned them. Shatter triggered. For a moment, they pause — then they understand. This is Pillar 2 working at the depth layer: the player learned something the game never told them, and it feels like power earned.

The system also has a failure mode worth designing for: *invisible damage*. If status ticks fire without a clear visual — no damage number, no overlay, no audio — the player loses the thread. A Burn they can't see feels like a bug, not a mechanic. Every status effect must produce a persistent visual indicator for its full duration and a distinct signal on each tick. The discovery of the second layer requires the first layer to be unambiguous.

## Detailed Design

### Core Rules

> *Specialist agents not consulted — Lean mode. Review manually before production.*

**1. Node type and lifecycle.** `StatusEffectsManager` is a Godot Autoload singleton. In `_ready()`, it connects to:
- `HealthDamage.enemy_killed` → `_on_enemy_killed(id, type_id, affiliation)` — remove all statuses for that instance
- `GameStateManager.preparation_started` → `_on_preparation_started()` — clear all active statuses

`process_mode = PROCESS_MODE_PAUSABLE`. All tick timers and duration counters run in `_process(delta)` using float accumulators — no `SceneTree.create_timer()` or `Timer` nodes.

---

**2. StatusInstance data structure.** Each active status is tracked as a `StatusInstance` object (GDScript class, not a Node):

| Field | Type | Description |
|-------|------|-------------|
| `target` | Node | The node this status is applied to |
| `status_type` | GameEnums.BaseStatus | BURN, BLIND, STUN, FREEZE, or REGENERATE |
| `duration_remaining` | float | Seconds remaining; decremented each frame |
| `tick_interval` | float | Seconds between ticks (Burn: 0.5s; Regen: 1.0s; Freeze/Blind/Stun: 0.0 — no ticks) |
| `tick_timer` | float | Accumulator counting down to next tick; reset to `tick_interval` after each tick |
| `spell_base_damage` | float | Base spell damage at application time; used by Burn to compute tick damage. 0.0 for non-damage statuses |

The registry is a `Dictionary[int, Array[StatusInstance]]` keyed by `target.get_instance_id()`. Lookup: `_active_statuses.get(target_id, [])`.

---

**3. Target scope:**

| Status | Applies to | Rationale |
|--------|-----------|-----------|
| Burn | Enemies only | Offensive DoT |
| Freeze | Enemies only | Movement control |
| Blind | Enemies only (stub) | Offensive debuff |
| Stun | Enemies only (stub) | Offensive debuff |
| Regenerate | Fayde only | The only MVP heal source (per H&D GDD Rule 4); enemies have no heal mechanic at MVP |
| Chill | Enemies only (stub) | Deepfrost non-primary 15% movement slow; suppressed if FREEZE already active on same target |
| Stagger | Enemies only (stub) | Voidblue T2 brief interrupt; same Enemy AI interface as Stun with 0.3s fixed duration |

`apply_status` must validate target scope and log an error for invalid calls (e.g., trying to apply Burn to Fayde). No gameplay processing if the target is out of scope.

**Note**: Despite the "1–2 effects" simplification estimate in the systems index, Regenerate must be fully wired at MVP because Health & Damage identifies it as Verdant's only healing path at MVP scope. Revised MVP scope: **Burn + Freeze + Regenerate fully wired; Blind + Stun as structured stubs** (visual indicator, duration tracking, no tick logic).

---

**4. Public API: `apply_status(target: Node, status_type: GameEnums.BaseStatus, duration: float, spell_base_damage: float = 0.0)`**

Called by Spell Casting & Effects on every spell hit that carries a `base_status`. Steps:
1. Validate target scope (Rule 3). Log error and return on mismatch.
1a. **Check target is alive**: `if not target.is_alive(): push_error(...); return` — prevents StatusInstance creation when `enemy_killed` and a spell hit resolve in the same frame (see Edge Case 1 and Open Question 2). All valid target node types must expose `is_alive() -> bool`.
2. Look up `_active_statuses[target.get_instance_id()]`. Search for an existing `StatusInstance` with matching `status_type`.
3. **If found (re-apply):** Reset `duration_remaining = duration`. Reset `tick_timer = 0` (next tick fires at the next tick interval). Update `spell_base_damage`. Emit `status_applied(target, status_type, duration)`.
4. **If not found (new application):** Create a `StatusInstance` with the provided values. Set `tick_timer = tick_interval` (first tick fires after one interval, not immediately). Append to `_active_statuses[target_id]`. Emit `status_applied(target, status_type, duration)`.
5. For FREEZE: call `target.apply_speed_modifier(1.0 - FREEZE_SLOW_PCT)` on the target node. Enemy AI must expose `apply_speed_modifier(multiplier: float)` — see Interactions.
6. For STUN (stub): call `target.apply_stun(duration)` on the target node. Enemy AI must expose `apply_stun(duration: float)` — zeroes velocity and freezes direction tracking for the given duration. Self-terminating in Enemy AI; StatusEffectsManager tracks the instance for the expiry signal and wave-clear cleanup only.
7. For CHILL (stub): if an active FREEZE StatusInstance exists for the same target (search `_active_statuses`), suppress — no StatusInstance created, no method call. FREEZE (50% slow) already exceeds CHILL's 15% slow effect. If FREEZE is not active, call `target.apply_speed_modifier(1.0 - CHILL_SLOW_PCT)` on new application. On expiry, call `target.apply_speed_modifier(1.0)`.
8. For STAGGER (stub): call `target.apply_stun(STAGGER_DURATION)` — fixed 0.3s; uses the same Enemy AI `apply_stun` interface as STUN. No tick logic. Self-terminating in Enemy AI.

---

**4a. Public API: `has_status(target: Node, status_type: GameEnums.BaseStatus) -> bool`**

Returns `true` if `_active_statuses[target.get_instance_id()]` contains a StatusInstance with matching `status_type`. Returns `false` if the target has no registered statuses or the `status_type` is not present.

**At First Playable scope:** StatusEffectsManager is not yet wired to SC&E's FP status stub field-writes (`target.status_freeze_timer`, etc.) — it does not create StatusInstances for FP status applications. `has_status` returns `false` for all FP stubs. Shatter and other Freeze-conditional effects are inert at FP. This is intentional and expected. At MVP when StatusEffectsManager owns Freeze tracking, `has_status(target, FREEZE)` becomes reliable.

*Additional public API: `check_and_apply_shatter(target, base_damage) -> float` is defined in Rule 10.*

> ⚠ **SC&E cross-GDD update required:** SC&E Formula 3 Step 5 currently inlines `if target.has_status(STATUS_FREEZE):` as a method call on the enemy node. At MVP this must be replaced with `StatusEffectsManager.check_and_apply_shatter(target, raw_damage)` so that Status Effects is the sole Shatter authority.

---

**5. Tick loop: `_process(delta)`**

For each `StatusInstance` in `_active_statuses` (iterating a copy of the array to safely handle mid-loop expiry):
1. `instance.duration_remaining -= delta`
2. If `instance.tick_interval > 0.0` (ticking status):
   a. `instance.tick_timer -= delta`
   b. If `instance.tick_timer <= 0.0`: fire tick (Rule 6), reset `instance.tick_timer = instance.tick_interval`
3. If `instance.duration_remaining <= 0.0`: expire the status (Rule 7)

> **Stun/Freeze pause (VS scope):** Prana Data (PD-28/PD-35) specifies that Stun should pause the Freeze timer. At MVP, Stun is a stub — `duration_remaining` decrements for all StatusInstances unconditionally, including FREEZE during a STUN window. This is a known simplification. At Vertical Slice when Stun is fully wired, the loop must be extended to skip `duration_remaining` decrement for non-Stun statuses while a STUN instance is active on the same target. See Open Question 1.

---

**6. Tick execution per effect:**

| Status | Tick interval | Tick action |
|--------|--------------|-------------|
| Burn | 0.5s | `HealthDamage.apply_damage(target, spell_base_damage × BURN_TICK_MAGNITUDE, null, DamageSource.DOT)` |
| Regenerate | 1.0s | `HealthDamage.apply_heal(target, FAYDE_MAX_HP × REGEN_TICK_MAGNITUDE)` |
| Freeze | — (no tick) | Duration only; `apply_speed_modifier(0.50)` pushed to Enemy AI on apply; `apply_speed_modifier(1.0)` on expiry (Rule 4 steps 5 and 7) |
| Blind (stub) | — | Duration only; miss-chance logic deferred to Vertical Slice |
| Stun (stub) | — | Duration only; interrupt on apply via `target.apply_stun(duration)` (self-terminating in Enemy AI) |
| Chill (stub) | — | Duration only; `target.apply_speed_modifier(1.0 - CHILL_SLOW_PCT)` on apply; `target.apply_speed_modifier(1.0)` on expiry. Suppressed if FREEZE active. |
| Stagger (stub) | — | Duration only (0.3s fixed); interrupt on apply via `target.apply_stun(STAGGER_DURATION)` (self-terminating in Enemy AI) |

*Burn tick damage uses `spell_base_damage` captured at application time — not recalculated from current combat state. A re-apply replaces `spell_base_damage` with the new value.*

---

**7. Status expiry**

When `duration_remaining <= 0`:
1. Remove `StatusInstance` from `_active_statuses[target_id]`
2. Emit `status_expired(target, status_type)`
3. Cleanup per type:
   - **Freeze**: call `target.apply_speed_modifier(1.0)` to restore full speed. Enemy AI resumes normal movement.
   - **Burn**: no cleanup (ticks stop; last tick may have already fired on the same frame).
   - **Stun (stub)**: no cleanup call — `apply_stun(duration)` is self-terminating in Enemy AI. Emit `status_expired` signal for VFX overlay removal only.
   - **Blind (stub)**: no runtime cleanup at MVP; emit signal only for VFX overlay removal.
   - **Regenerate**: no cleanup (healing just stops).
   - **Chill (stub)**: call `target.apply_speed_modifier(1.0)` to restore full speed. (Chill instances are only created when FREEZE was not active; no conflict on expiry.)
   - **Stagger (stub)**: no cleanup call — self-terminating in Enemy AI. Emit `status_expired` signal only.

---

**8. Target death cleanup**

On `HealthDamage.enemy_killed(id, type_id, affiliation)`: remove all `StatusInstance` entries for the dead target from `_active_statuses`. Call expiry cleanup callbacks (Rule 7 step 3) **without** emitting `status_expired` signals (VFX cleanup is handled by death animation). If Burn Contagion applies (Rule 10), process it **before** removing the Burn instance.

---

**9. Wave/phase clear**

On `GameStateManager.preparation_started`: clear all entries in `_active_statuses`. Call expiry cleanup for each (Rule 7 step 3) to ensure target nodes are restored to normal state (Freeze released, Stun released). No signals emitted — wave has ended.

---

**10. Conditional depth behaviours (MVP scope: Burn Contagion + Shatter)**

**Burn Contagion (Ashfire)** — Fires on enemy death while Burning:
- Triggered inside `_on_enemy_killed()`, before removing the Burn instance: if the dying enemy has an active BURN status:
  - Find the nearest living enemy within `BURN_CONTAGION_RANGE` (200px) using a distance scan of active enemies.
  - If found: call `apply_status(nearest_enemy, BURN, BURN_CONTAGION_DURATION, original_spell_base_damage)`. `BURN_CONTAGION_DURATION` is fixed at 2.0s — not the tunable `burn_duration`.
  - Emit `burn_contagion_triggered(dying_enemy_position: Vector2, to_target: Node)` for VFX.
  - If no enemy in range: no transfer. No fallback.

**Shatter (Deepfrost)** — +25% bonus on any DIRECT hit against a Frozen target:
- Status Effects exposes `check_and_apply_shatter(target: Node, base_damage: float) -> float`:
  - If `has_status(target, FREEZE)`: emit `shatter_triggered(target)`; return `base_damage × SHATTER_MULTIPLIER` (1.25).
  - Else: return `base_damage` unchanged.
- SC&E calls `check_and_apply_shatter(primary_target, raw_base_damage)` and passes the returned value as `base_damage` to `HealthDamage.apply_damage` for every DIRECT spell hit.
- Shatter does **not** end the Freeze status — the target remains Frozen for its remaining duration.
- Enemy CONTACT hits on Fayde are not subject to Shatter at MVP (Freeze only targets enemies).

**Stub conditional behaviours (deferred to Vertical Slice):**
- Deepening Doubt (Blind): Blind timer extension per missed attack
- Lightning Follow-Through (Stun): +30% on Stormgold cast within 1.5s of a Stun interrupt
- Injury Bloom (Regenerate): extra Regen tick on CONTACT hit while Regen active on Fayde

---

### States and Transitions

**Per-StatusInstance states:**

| State | Condition | Transition |
|-------|-----------|------------|
| `ACTIVE` | `duration_remaining > 0` | → `EXPIRED` when `duration_remaining <= 0` |
| `EXPIRED` | `duration_remaining <= 0` | Terminal — removed from registry |

Re-apply (Rule 4 step 3) resets the instance's `duration_remaining` without changing state (stays `ACTIVE`).

**System-level states:**

| State | Condition |
|-------|-----------|
| `IDLE` | No active StatusInstances, or PREPARATION_PHASE |
| `PROCESSING` | One or more StatusInstances active during COMBAT_PHASE |

`IDLE → PROCESSING`: first `apply_status` call in COMBAT_PHASE.
`PROCESSING → IDLE`: all instances expire, or `preparation_started` fires (Rule 9).

---

### Interactions with Other Systems

| System | Interface | Direction | Notes |
|--------|-----------|-----------|-------|
| **Spell Casting & Effects** | Calls `apply_status(target, status_type, duration, spell_base_damage)` after each spell hit; calls `check_and_apply_shatter(target, base_damage) -> float` before each DIRECT `apply_damage` call | SC&E → StatusEffects | SC&E drives all status application; Status Effects is passive until called |
| **Health & Damage** | StatusEffects calls `apply_damage(target, tick_damage, null, DamageSource.DOT)` per Burn tick; calls `apply_heal(fayde, tick_heal)` per Regen tick; listens to `enemy_killed` for cleanup | StatusEffects ↔ H&D | H&D owns HP math; Status Effects owns tick timing. No circular dependency: H&D emits signals; Status Effects listens and calls H&D methods |
| **Enemy AI** | Enemy AI nodes must expose `apply_speed_modifier(multiplier: float)` — called by Status Effects on Freeze/Chill apply and expiry; Enemy AI stores `_speed_multiplier` and applies it each physics frame. Must also expose `apply_stun(duration: float)` — called on Stun and Stagger apply (self-terminating timer in Enemy AI); StatusEffectsManager tracks the instance for expiry signal and wave-clear cleanup only | StatusEffects → Enemy AI | Status Effects pushes speed and stun commands; Enemy AI enforces behavior |
| **Game State & Scene Flow** | Listens to `preparation_started` → clear all statuses | GS&SF → StatusEffects | Phase transition cleanup |
| **Prana Data** | Reads Burn/Freeze/Regen parameters at startup via constants (`BURN_TICK_MAGNITUDE`, `FREEZE_SLOW_PCT`, etc.) — all registered in entities.yaml | StatusEffects reads Prana Data constants | All parameter values locked by Prana Data GDD; Status Effects must not redefine them |
| **VFX pipeline** | Emits `status_applied(target, type, duration)`, `status_expired(target, type)`, `burn_contagion_triggered(from_pos, to_target)`, `shatter_triggered(target)` | StatusEffects → VFX | Status Effects is a signal source; VFX pipeline listens and renders overlays |
| **Combat HUD** | Listens to `status_applied` and `status_expired` (future: status icons in HUD are VS scope; MVP status visuals are VFX overlays on enemy sprites) | StatusEffects → Combat HUD | Status icon tracking is VS scope |

## Formulas

### Formula 1 — Burn Tick Damage

```
burn_tick_damage = max(0, spell_base_damage) × BURN_TICK_MAGNITUDE
```

Applied 4 times across the 2.0s duration (once per 0.5s tick interval). Total damage over full duration = `burn_tick_damage × 4`.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Spell base damage at application | `spell_base_damage` | float | 0.0 – unbounded | The `base_damage` value passed to `apply_status`. Captured once at application; a re-apply updates this value. |
| Burn tick magnitude | `BURN_TICK_MAGNITUDE` | float | 0.08 (constant) | Fraction of `spell_base_damage` per tick. Defined in Prana Data. |
| Tick count | — | int | 4 | `burn_duration (2.0s) / tick_interval (0.5s)`. |

**Output range:** 0.0 – unbounded (scales with caster's spell power). Each tick is passed to `HealthDamage.apply_damage` with `element = null, source = DamageSource.DOT`.

**Worked examples:**

| Scenario | `spell_base_damage` | `burn_tick_damage` | Total Burn damage (4 ticks) |
|----------|---------------------|--------------------|-----------------------------|
| Standard Ashfire spell (base=20) | 20.0 | 1.6 → rounded by H&D to **2** | **8** |
| High-power Ashfire combo (base=40) | 40.0 | 3.2 → rounded to **3** | **12** |
| Re-applied with new base=30 | 30.0 | 2.4 → rounded to **2** | **8** (4 ticks at new rate) |

*H&D's `apply_damage` applies `roundi()` to the incoming value. The `max(0, ...)` guard prevents negative inputs creating a healing DoT.*

**Registry reference:** `burn_total` formula (entities.yaml). `burn_tick_magnitude` constant = 0.08. `burn_duration` constant = 2.0s.

> **Interface limitation (VS scope):** `ADJ_BURN_INTENSIFY` (+0.04) and `ASH_BURN_TICK` (+0.06) from Combination Resolution require raising `burn_tick_magnitude` per-application. The current `apply_status(target, status_type, duration, spell_base_damage)` interface has no parameter for a modified tick magnitude — at MVP all Burn ticks use the constant `BURN_TICK_MAGNITUDE = 0.08`. A fifth parameter or replacement call pattern is deferred to Vertical Slice.

---

### Formula 2 — Regen Tick Heal

```
regen_tick_heal = FAYDE_MAX_HP × REGEN_TICK_MAGNITUDE
```

Applied 3 times across the 3.0s duration (once per 1.0s tick interval). Total healing = `regen_tick_heal × 3`.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Fayde max HP | `FAYDE_MAX_HP` | int | 80 – 150 | Constant from H&D. Default 100. |
| Regen tick magnitude | `REGEN_TICK_MAGNITUDE` | float | 0.02 (constant) | Fraction of FAYDE_MAX_HP per tick. Defined in Prana Data. |

**Output range:** At default FAYDE_MAX_HP=100: 2 HP/tick (H&D rounds `roundi(2.0) = 2`). Total: **6 HP** per cast.

**Minimum safe floor:** At FAYDE_MAX_HP=80, tick value = `round(80 × 0.02) = round(1.6) = 2` HP — safely nonzero. Do not reduce REGEN_TICK_MAGNITUDE below 0.02.

**Registry reference:** `regen_total` formula (entities.yaml). `regen_tick_magnitude` constant = 0.02. `regen_duration` constant = 3.0s. `fayde_max_hp` constant = 100.

---

### Formula 3 — Effective Move Speed Under Freeze

Defined and owned by the Enemy Data GDD (entities.yaml). Referenced here:

```
effective_move_speed = base_move_speed × max(0, 1 − slow_percentage)
```

Status Effects calls `target.apply_speed_modifier(1.0 - FREEZE_SLOW_PCT)` (= `apply_speed_modifier(0.50)`) when Freeze is applied, and `target.apply_speed_modifier(1.0)` when Freeze expires. Enemy AI stores the multiplier as `_speed_multiplier` and applies it in `_physics_process`. Enemy AI owns the formula evaluation; Status Effects owns the timing and the push call.

**Output range:** 0.0 – `base_move_speed`. At FREEZE_SLOW_PCT=0.50 and base_move_speed=80 (Drifter): Status Effects pushes `apply_speed_modifier(0.50)` → Enemy AI computes `80 × 0.50 = 40 px/s` during Freeze.

**Registry reference:** `effective_move_speed` formula (entities.yaml, owned by enemy-data.md). `freeze_slow_pct` constant = 0.50.

---

### Formula 4 — Shatter Bonus (Deepfrost conditional)

```
shattered_base_damage = base_damage × SHATTER_MULTIPLIER
```

Applied by `check_and_apply_shatter(target, base_damage)` when target has active FREEZE. SC&E calls this before passing `base_damage` to `HealthDamage.apply_damage` for DIRECT hits.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Pre-Shatter base damage | `base_damage` | float | 0.0 – unbounded | The damage value SC&E computed before the Shatter check. |
| Shatter multiplier | `SHATTER_MULTIPLIER` | float | 1.25 (constant) | +25% bonus. Defined in Prana Data Rule 7. |

**Output range:** `base_damage` × 1.25. The result feeds H&D's full damage pipeline (elemental multiplier, `roundi`, clamp).

**Worked example:** Deepfrost T1 (base=20 × modifier=0.80 = 16.0), target Frozen: `16.0 × 1.25 = 20.0 → roundi(20.0) = 20`. Without Shatter: `roundi(16.0) = 16`. Bonus: 4 damage.

**Design note — Shatter cancels Deepfrost's damage penalty:** `base_damage_modifier=0.80 × SHATTER_MULTIPLIER=1.25 = 1.00`. A Deepfrost hit on a Frozen enemy deals neutral damage — exactly the same as a neutral-type hit. Freeze's value is the 2.0s root + cast window, not a damage amp. This is intentional.

*`SHATTER_MULTIPLIER` is registered in entities.yaml (source: prana-data.md, added 2026-05-29). Changes must be made in Prana Data first, then the registry updated.*

---

### Formula 5 — Burn Contagion Range Check

No formula. The mechanic is a nearest-enemy range check:
- Distance metric: 2D Euclidean distance from dying enemy's position to each living enemy's position
- Transfer condition: `distance <= BURN_CONTAGION_RANGE` (200px)
- Target selection: enemy with the smallest qualifying distance
- Transfer parameters: `BURN_CONTAGION_DURATION = 2.0s` (fixed, not tunable), same `spell_base_damage` as the original Burn

*`BURN_CONTAGION_RANGE` (200px) and `BURN_CONTAGION_DURATION` (2.0s) are defined in Prana Data Rule 7 and registered in entities.yaml (source: prana-data.md, added 2026-05-29). Changes must be made in Prana Data first, then the registry updated.*

## Edge Cases

1. **If `apply_status` is called on a dead target** (`current_hp <= 0`): return immediately — no StatusInstance created, no signal emitted, no VFX. Prevents zombie status applications when `enemy_killed` and a spell hit resolve in the same frame.

2. **If Burn is re-applied while active on the same target**: reset `duration_remaining` to the new duration; reset `tick_timer = 0`; update `spell_base_damage`. Total remaining ticks restart from 4. A re-apply at tick 3 (only 1 tick remaining) fully restores 4 ticks of damage potential.

3. **If an enemy dies mid-Burn tick** (tick accumulator is counting when `enemy_killed` fires): the unfired tick is silently dropped. Burn Contagion uses the `spell_base_damage` from the dying instance before cleanup. No partial-tick damage is calculated.

4. **If Burn Contagion targets the only enemy on screen** (the last wave enemy): `apply_status` is called normally. If `preparation_started` fires before any Contagion ticks land, the Burn is cleared. Status Effects does not check wave state before transferring Contagion — the phase transition is authoritative.

5. **If Freeze is applied while already active**: replace rule resets `duration_remaining`; `set_freeze_state(true)` is a no-op since the target is already frozen. No visual flicker; Enemy AI freeze state remains unchanged.

6. **If a Frozen enemy takes DIRECT damage from multiple spell hits in the same frame**: `check_and_apply_shatter` is called independently for each hit. Shatter fires on every qualifying hit. Freeze is not consumed by Shatter — it runs to its full duration.

7. **If `apply_status` is called with `duration <= 0`**: log an error and return immediately. A zero-duration status would expire on the same frame with no ticks and no effect. Callers must validate duration.

8. **If Burn Contagion range query finds no living enemies within 200px**: no transfer. No fallback. Status Effects takes no further action.

9. **If Regen is applied to an enemy** (invalid target scope): log an error and return. No StatusInstance created. Regen is Fayde-only; calling it on an enemy is a caller bug.

10. **If a Burn tick fires on an enemy already at `current_hp = 0`** (race condition — tick fires in the same frame as `enemy_killed`): H&D's dead-target guard returns immediately — no damage, no signal. The tick is harmless.

11. **If `preparation_started` fires while tick accumulators are mid-countdown**: `_on_preparation_started` clears all StatusInstances before the tick loop runs on remaining instances. Any cleared instances are absent from the registry — the loop skips them. In-progress ticks for the current frame that fired before the clear are already applied and cannot be rolled back (acceptable).

12. **If Regen is active when Fayde dies**: any subsequent Regen ticks that fire before `preparation_started` call `apply_heal(fayde, ...)`. H&D's dead-target guard blocks the heal — `current_hp = 0` means `DEAD` state, all `apply_damage` and `apply_heal` calls return immediately. Status Effects does not need to listen to `player_died`; the next `preparation_started` clears all statuses normally.

## Dependencies

| # | System | Relationship | Direction | Notes |
|---|--------|-------------|-----------|-------|
| 1 | **Health & Damage** | StatusEffects calls `apply_damage(target, tick_damage, null, DamageSource.DOT)` per Burn tick and `apply_heal(fayde, tick_heal)` per Regen tick; listens to `enemy_killed` for cleanup; H&D's dead-target guard blocks ticks on dead targets | Status Effects → H&D (calls) + H&D → Status Effects (signal) | H&D is the HP authority; Status Effects is the tick-timer authority. No circular dependency. |
| 2 | **Spell Casting & Effects** | Calls `apply_status(target, status_type, duration, spell_base_damage)` for every hit with a `base_status`; calls `check_and_apply_shatter(target, base_damage) -> float` before every DIRECT `apply_damage` call | SC&E → Status Effects | SC&E is the sole caller of `apply_status` at MVP scope |
| 3 | **Prana Data** | Reads all status-effect constants at startup: `BURN_TICK_MAGNITUDE` (0.08), `BURN_DURATION` (2.0s), `BLIND_MISS_CHANCE` (0.50), `BLIND_DURATION` (2.0s), `STUN_DURATION` (0.8s), `FREEZE_DURATION` (2.0s), `FREEZE_SLOW_PCT` (0.50), `REGEN_TICK_MAGNITUDE` (0.02), `REGEN_DURATION` (3.0s) | Prana Data → Status Effects (read-only) | Prana Data owns all values; Status Effects must not redefine them |
| 4 | **Enemy AI** | Enemy AI nodes must expose `apply_speed_modifier(multiplier: float)` — called on Freeze/Chill apply and expiry (push-multiplier pattern); Enemy AI stores `_speed_multiplier` and applies it in `_physics_process`. Must also expose `apply_stun(duration: float)` — called on Stun and Stagger apply (self-terminating in Enemy AI); StatusEffectsManager tracks the instance for expiry signal and wave-clear cleanup | Status Effects → Enemy AI | Status Effects pushes speed/stun commands; Enemy AI enforces movement constraint. ⚠ **Cross-GDD flag**: Enemy AI GDD must formally define `apply_speed_modifier(float)` and `apply_stun(float)` method signatures before Status Effects MVP implementation begins |
| 5 | **Game State & Scene Flow** | Listens to `preparation_started` → clears all active statuses | GS&SF → Status Effects | Phase transition is the authoritative clear signal |
| 6 | **VFX pipeline** | Emits `status_applied(target, type, duration)`, `status_expired(target, type)`, `burn_contagion_triggered(from_pos: Vector2, to_target: Node)`, `shatter_triggered(target: Node)` | Status Effects → VFX | VFX owns visual specs; Status Effects owns signal timing |

**Bidirectionality note:** Health & Damage (Dependency #3 in H&D GDD) lists Status Effects. SC&E must list Status Effects in its Dependencies section and update Formula 3 Step 5 to call `StatusEffectsManager.check_and_apply_shatter(target, raw_damage)` (not `target.has_status`). Enemy AI must add Status Effects as a dependency and expose `apply_speed_modifier(float)` and `apply_stun(float)` methods.

> ⚠ **GameEnums update required:** `STATUS_CHILL` and `STATUS_STAGGER` must be added to `GameEnums.BaseStatus` before any code using `apply_status` with these types is compiled. Owner: Prana Data GDD or GameEnums resource authoring.

> ⚠ **SC&E cross-GDD update required (Burn interface gap):** SC&E Rule 8 describes `apply_status` calls with 3 arguments only (`target, status_id, effective_duration`). The 4th parameter `spell_base_damage` defaults to `0.0` — Burn ticks would deal `0.0 × BURN_TICK_MAGNITUDE = 0` damage. SC&E Rule 8 must be updated to pass `effective_base` (= `BASE_SPELL_DAMAGE + flat_stat_bonus`, from SC&E Formula 3 Steps 1–2) as the 4th argument for Burn applications: `apply_status(target, BURN, effective_duration, effective_base)`. Required before any Burn implementation begins.

## Tuning Knobs

| Knob | Constant Name | Default Value | Safe Range | What It Affects |
|------|---------------|---------------|------------|----------------|
| Burn duration | `BURN_DURATION` | 2.0s | 1.0s – 4.0s | Total Burn window. 4 ticks spread across this duration (tick_interval = `BURN_DURATION / 4`). Raising makes Burn a sustained threat; lowering makes it a burst. *Owned by Prana Data.* |
| Burn tick magnitude | `BURN_TICK_MAGNITUDE` | 0.08 | 0.05 – 0.15 | Per-tick DoT fraction of spell base damage. 0.08 × 4 = 32% total. Raising above 0.15 risks Burn outdamaging the direct hit on powerful spells. *Owned by Prana Data.* |
| Freeze duration | `FREEZE_DURATION` | 2.0s | 0.5s – 3.0s | How long the Freeze root lasts. At 0.5s: barely a stagger. At 3.0s: trivializes single enemies. 2.0s is calibrated for 1–2 follow-up cast windows. *Owned by Prana Data.* |
| Freeze slow percentage | `FREEZE_SLOW_PCT` | 0.50 | 0.20 – 0.70 | Movement speed reduction during Freeze. 0.50 = half speed; 0.70 = near-full root. *Owned by Prana Data.* |
| Regen tick magnitude | `REGEN_TICK_MAGNITUDE` | 0.02 | 0.02 – 0.05 | Per-tick heal fraction of FAYDE_MAX_HP. 0.02 × 100 × 3 = 6 HP total — intentionally weak in isolation. Do not reduce below 0.02 (minimum nonzero at FAYDE_MAX_HP=80). *Owned by Prana Data.* |
| Regen duration | `REGEN_DURATION` | 3.0s | 2.0s – 5.0s | Total Regen window (3 ticks at 1.0s interval). Raising extends duration without changing per-tick value. *Owned by Prana Data.* |
| Burn Contagion range | `BURN_CONTAGION_RANGE` | 200px | 80px – 400px | Distance within which Burn Contagion transfers on death. At 80px: rarely triggers in open arenas. At 400px: triggers across most of an 800px-wide arena. Calibrate to reward enemy clustering without making Contagion a guaranteed chain. |
| Burn Contagion duration | `BURN_CONTAGION_DURATION` | 2.0s | 1.0s – 2.0s | Fixed duration of the transferred Burn. Intentionally capped: Contagion cannot cascade at maximum configured duration. Maximum safe = `BURN_DURATION` default. |
| Shatter multiplier | `SHATTER_MULTIPLIER` | 1.25 | 1.10 – 1.50 | Bonus damage multiplier on DIRECT hits vs Frozen targets. At 1.25: exactly cancels Deepfrost's 0.80 damage modifier (neutral parity on frozen targets). Above 1.50 makes Deepfrost the strongest damage type when combined with Freeze — breaks the "control, not damage" design intent. |

**Cross-system tuning notes:**
- `BURN_DURATION`, `BURN_TICK_MAGNITUDE`, `FREEZE_DURATION`, `FREEZE_SLOW_PCT`, `REGEN_TICK_MAGNITUDE`, and `REGEN_DURATION` are owned by Prana Data GDD. Changes require updating Prana Data.
- `BURN_CONTAGION_RANGE`, `BURN_CONTAGION_DURATION`, and `SHATTER_MULTIPLIER` are defined in Prana Data GDD and registered in entities.yaml with source: prana-data.md. This GDD is a consumer. Changes require updating Prana Data first.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

> *`qa-lead` not consulted — Lean mode. Review manually before production.*

**Burn — apply and tick:**

- **AC-SE-01** — GIVEN an enemy with no active statuses, WHEN `apply_status(enemy, BURN, 2.0, 20.0)` is called, THEN `_active_statuses` contains one Burn StatusInstance for that enemy with `duration_remaining ≈ 2.0s` and `status_applied(enemy, BURN, 2.0)` is emitted once.
- **AC-SE-02** — GIVEN an enemy with an active Burn StatusInstance (`tick_interval=0.5s`, `spell_base_damage=20.0`), WHEN 0.5s elapses in `_process(delta)`, THEN `HealthDamage.apply_damage(enemy, 1.6, null, DamageSource.DOT)` was called once. *(20.0 × 0.08 = 1.6; the assertion is on the value passed to H&D, not H&D's rounded output.)*
- **AC-SE-03** — GIVEN an active Burn instance whose `duration_remaining` reaches 0, THEN the StatusInstance is removed from `_active_statuses` and `status_expired(enemy, BURN)` is emitted once. No additional tick fires after expiry.

**Burn re-apply:**

- **AC-SE-04** — GIVEN an enemy with 1.0s remaining on an active Burn (`spell_base_damage=20.0`), WHEN `apply_status(enemy, BURN, 2.0, 30.0)` is called, THEN `duration_remaining ≈ 2.0s` (reset); `spell_base_damage = 30.0` (updated); exactly **one** Burn StatusInstance exists for this enemy (not two); `status_applied` emitted once.

**Freeze — apply, movement lock, expiry:**

- **AC-SE-05** — GIVEN a Drifter enemy with normal movement, WHEN `apply_status(drifter, FREEZE, 2.0, 0.0)` is called, THEN `drifter.apply_speed_modifier(0.50)` was called exactly once; `has_status(drifter, FREEZE)` returns `true`.
- **AC-SE-06** — GIVEN a Drifter with active Freeze that expires naturally, WHEN `duration_remaining` reaches 0, THEN `drifter.apply_speed_modifier(1.0)` was called and `has_status(drifter, FREEZE)` returns `false`.
- **AC-SE-07** — GIVEN a Frozen Drifter, WHEN Freeze is re-applied, THEN `apply_speed_modifier` is NOT called a second time (no-op — multiplier already applied); `duration_remaining ≈ 2.0s`; exactly **one** Freeze StatusInstance exists.

**Regen — apply and tick:**

- **AC-SE-08** — GIVEN Fayde at `current_hp=80` and `apply_status(fayde, REGENERATE, 3.0, 0.0)` is called, WHEN 1.0s elapses, THEN `HealthDamage.apply_heal(fayde, 2.0)` was called once. WHEN 3.0s total elapse, THEN `apply_heal` was called exactly 3 times.

**Target scope guard:**

- **AC-SE-09** — GIVEN `apply_status(fayde, BURN, 2.0, 20.0)` is called (Burn is enemies-only), THEN no StatusInstance is created; an error is logged; `status_applied` is NOT emitted.
- **AC-SE-10** — GIVEN `apply_status(enemy, REGENERATE, 3.0, 0.0)` is called (Regen is Fayde-only), THEN no StatusInstance is created; an error is logged; `status_applied` is NOT emitted.

**Dead target guard:**

- **AC-SE-11** — GIVEN an enemy with `current_hp=0`, WHEN `apply_status(enemy, BURN, 2.0, 20.0)` is called, THEN no StatusInstance is created and `status_applied` is NOT emitted.

**Target death cleanup:**

- **AC-SE-12** — GIVEN an enemy with active Burn AND active Freeze, WHEN `HealthDamage.enemy_killed` fires for that enemy, THEN both StatusInstances are removed from `_active_statuses`; `apply_speed_modifier(1.0)` was called on the enemy node (Freeze cleanup restores full speed); no further tick calls are made for that enemy.

**Burn Contagion:**

- **AC-SE-13** — GIVEN an enemy with active Burn (`spell_base_damage=20.0`) dies while a second enemy is within 200px, WHEN `enemy_killed` fires, THEN `apply_status(second_enemy, BURN, 2.0, 20.0)` is called and `burn_contagion_triggered(dying_pos, second_enemy)` is emitted once.
- **AC-SE-14** — GIVEN an enemy with active Burn dies while NO other enemy is within 200px, THEN no Contagion transfer occurs and `burn_contagion_triggered` is NOT emitted.
- **AC-SE-15** — GIVEN an enemy with active Burn dies while a second enemy is 201px away (outside range), THEN Contagion does NOT transfer.

**Shatter:**

- **AC-SE-16** — GIVEN an enemy with active Freeze, WHEN `check_and_apply_shatter(enemy, 16.0)` is called, THEN the return value is `20.0` (`16.0 × 1.25`) and `shatter_triggered(enemy)` is emitted once.
- **AC-SE-17** — GIVEN an enemy WITHOUT active Freeze, WHEN `check_and_apply_shatter(enemy, 16.0)` is called, THEN the return value is `16.0` unchanged and `shatter_triggered` is NOT emitted.
- **AC-SE-18** — GIVEN a Frozen enemy hit by two DIRECT spells in the same frame, WHEN `check_and_apply_shatter` is called twice for the same target, THEN it returns the 1.25× value both times (Shatter is not consumed after the first hit). Freeze remains active.

**Wave/phase clear:**

- **AC-SE-19** — GIVEN enemies with active Burn and active Freeze, WHEN `preparation_started` fires, THEN `_active_statuses` is empty; `apply_speed_modifier(1.0)` was called on the Frozen enemy (restoring full speed); no tick fires after the clear.

**Zero-duration guard:**

- **AC-SE-20** — GIVEN `apply_status(enemy, BURN, 0.0, 20.0)` is called, THEN no StatusInstance is created and an error is logged.

**Regen total heal (Formula 2):**

- **AC-SE-21** — GIVEN Fayde at `current_hp=50` and `apply_status(fayde, REGENERATE, 3.0, 0.0)` called, WHEN 3.0s elapse (3 ticks at 1.0s interval), THEN `apply_heal` was called exactly 3 times with `tick_heal = 2.0` each; Fayde gains 6 HP total (H&D rounds each 2.0 to 2).

**Stub effects (Blind and Stun at MVP):**

- **AC-SE-22** — GIVEN `apply_status(enemy, BLIND, 2.0, 0.0)` is called, THEN a Blind StatusInstance is created; `status_applied(enemy, BLIND, 2.0)` is emitted; no tick logic fires; after 2.0s `status_expired(enemy, BLIND)` is emitted and the instance is removed.
- **AC-SE-23** — GIVEN `apply_status(enemy, STUN, 0.8, 0.0)` is called, THEN `enemy.apply_stun(0.8)` is called exactly once at application (self-terminating in Enemy AI); after 0.8s `status_expired(enemy, STUN)` is emitted when the StatusInstance's `duration_remaining` reaches 0. No second method call on expiry.

**Chill — suppression and apply:**

- **AC-SE-24** — GIVEN an enemy with an active FREEZE StatusInstance, WHEN `apply_status(enemy, CHILL, 2.0, 0.0)` is called, THEN no CHILL StatusInstance is created; `apply_speed_modifier` is NOT called a second time; `status_applied` is NOT emitted for CHILL.
- **AC-SE-25** — GIVEN an enemy with no active Freeze, WHEN `apply_status(enemy, CHILL, 2.0, 0.0)` is called, THEN a CHILL StatusInstance is created; `enemy.apply_speed_modifier(0.85)` was called once (1.0 − 0.15 = 0.85); `status_applied(enemy, CHILL, 2.0)` is emitted.
- **AC-SE-26** — GIVEN an enemy with an active Chill (no Freeze), WHEN the Chill StatusInstance expires, THEN `enemy.apply_speed_modifier(1.0)` is called and `has_status(enemy, CHILL)` returns `false`.

**Stagger — apply and self-terminate:**

- **AC-SE-27** — GIVEN `apply_status(enemy, STAGGER, 0.3, 0.0)` is called, THEN `enemy.apply_stun(0.3)` is called once at application; `status_applied(enemy, STAGGER, 0.3)` is emitted; after 0.3s `status_expired(enemy, STAGGER)` is emitted. No second method call on expiry.

## Open Questions

1. **Stun/Freeze timer pause (VS scope)** — Prana Data (PD-28/PD-35) specifies that applying Stun to a Frozen enemy pauses the Freeze timer. At MVP, Stun is a stub and `duration_remaining` decrements for all StatusInstances unconditionally — Freeze timer counts down during Stun. At Vertical Slice when Stun is fully implemented, the tick loop (Rule 5) must be extended: skip `duration_remaining` decrement for non-Stun statuses while a STUN instance is active on the same target. *Owner: Status Effects VS implementation.*

2. **Target alive-check mechanism** — Rule 4 step 1a requires `target.is_alive() -> bool`. All target node types (Enemy AI instances, Fayde) must expose this method returning `current_hp > 0`. Confirm this contract is included in Enemy AI and Player Controller GDDs before implementation. *Owner: Enemy AI GDD and Player Controller GDD cross-reference.*

3. **Shatter at FP scope (resolved — inert)** — At FP, StatusEffectsManager does not track status instances for SC&E's stub field-writes. `has_status(target, FREEZE)` returns `false` at FP. Shatter is inert. At MVP when StatusEffectsManager owns Freeze tracking, Shatter becomes active. No design action needed.

4. **GameEnums BaseStatus update** — `STATUS_CHILL` and `STATUS_STAGGER` must be added to `GameEnums.BaseStatus` before any code using `apply_status` with these types compiles. *Owner: Prana Data GDD or GameEnums resource — cross-GDD flag in Dependencies section.*
