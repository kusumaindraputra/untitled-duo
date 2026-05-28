# Spell Casting & Effects

> **Status**: Designed (pending /design-review)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-28
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding), Pillar 3 (Chaos Has Consequences)

## Overview

Spell Casting & Effects is the execution layer that translates Fayde's Prana grid arrangement into combat damage. When `combat_started` fires, it receives the resolved `SpellEffect` payload from Combination Resolution via `combo_resolved` — containing the primary type, tier, non-primary modifiers, adjacency effects, and wave-scoped stat bonuses — and holds it for the wave. When the player presses the cast action, it fires the pre-arranged attack chain: a sequence of 1–3 attacks (determined by `primary_tier`) with a `combo_continuation_window` between each press. For each hit, SC&E resolves the full damage chain — primary type's `base_damage_modifier`, tier attack scalar, stat property bonuses, non-primary modifier bonuses, adjacency effect modifiers, and elemental affiliation multiplier (2× if the spell element matches the target's affiliation, 1× otherwise) — then calls `apply_damage(target, base_damage, element, DamageSource.DIRECT)` on Health & Damage. SC&E also acts as the wave-scoped stat broker: Status Effects and Health & Damage query it for relevant stat delta values from `aggregate_stat_bonus` rather than reading the `SpellEffect` payload directly.

At First Playable scope, the system is simplified — damage resolution and the full CR modifier chain are implemented; status effect tick systems are stubs (`apply_status(target, status, duration)`, with tick timing owned by the future Status Effects GDD); and visual effects are minimal. All gameplay positions and hit detection operate in 2D screen-space cartesian coordinates per **ADR-0001** — the isometric projection is visual only.

From the player's perspective, SC&E is the payoff moment of every Preparation phase: the spell Fayde built for 5–15 seconds fires in a chain, and the Prana arrangement either exploits the wave's elemental affiliation or it doesn't. The system delivers no judgment — only the results of the decision the player already made.

## Player Fantasy

> *`creative-director` not consulted — Lean mode. Review manually before production.*

SC&E is where the Preparation phase proves its worth. For 5–15 seconds before combat, the player built a plan — Deepfrost in the centre to root the Charger, Ashfire neighbours to burn through the pack the moment it's frozen. Spell Casting & Effects is the system that fires that plan.

The primary fantasy is **confirmation of correct reading**: the chain resolves exactly as arranged, the elemental affiliation bonus doubles the damage on the enemy the player correctly identified, and the wave clears on the terms the player set. The satisfaction belongs entirely to the player. SC&E provided the mechanism; the player made the decision.

The secondary fantasy is **legible failure**. A misread arrangement — wrong primary type against a wave the player miscounted, non-primary modifiers that don't trigger because the fill count was too low — fires with full clarity. The player sees the numbers, sees the chain, and understands exactly which part of the arrangement was wrong. This is Pillar 3's contract: *surprise is a feature; confusion is a bug.* SC&E must never hide why a spell underperformed. The chain it fires is the chain the player built.

The edge case worth naming: the first-discovery moment, when a player triggers an adjacency effect or a non-primary modifier combination they hadn't used before and sees the result land unexpectedly well. That pause — *"wait, why did that do so much damage?"* — is the moment of understanding that Pillar 2 is designed to produce. SC&E delivers the result; the Prana grid makes it legible on inspection.

## Detailed Design

> *Specialist agents not consulted — Lean mode. Review manually before production.*

### Core Rules

**1. Node type and lifecycle.** SC&E is implemented as a Godot Autoload singleton (`SpellCastingEffects`). It connects to signals in `_ready()`:
- `GameStateManager.combat_started` → `_on_combat_started()`
- `GameStateManager.preparation_started` → `_on_preparation_started()`
- `CombinationResolution.combo_resolved` → `_on_combo_resolved(spell_effect)`

`process_mode = PROCESS_MODE_PAUSABLE`. Cast input is checked in `_process(delta)`; timing accumulators (combo window, cast lock, echo delay) use the float accumulator pattern in `_process(delta)` — not `SceneTree.create_timer()` or `Timer` nodes.

**2. State machine.** SC&E has four operative states:

| State | Condition |
|-------|-----------|
| `IDLE` | PREPARATION_PHASE, or no `SpellEffect` cached |
| `READY` | COMBAT_PHASE, `SpellEffect` cached, `_combo_index = 0` |
| `CHAINING` | `_combo_index ≥ 1`; combo window countdown active |
| `CAST_LOCKED` | Immediately after any hit fires; `CAST_LOCK_DURATION` countdown (default 0.12s; Ashfire uses 0.20s — see Rule 6) |

Cast input (`Input.is_action_just_pressed(&"cast")`) is only processed when `_state == READY OR CHAINING` and `_cast_lock_timer <= 0`.

**3. SpellEffect cache.** SC&E caches `_current_spell_effect: SpellEffect` for the full wave after receiving `combo_resolved`. Cache is cleared to `null` on `preparation_started`. SC&E is the wave-scoped stat broker — exposes `get_stat_bonus(stat_id: StringName) → float` returning `_current_spell_effect.aggregate_stat_bonus.get(stat_id, 0.0)` (returns 0.0 if cache is null). Status Effects (MVP) and Health & Damage query SC&E via this method rather than accessing `SpellEffect` directly.

**4. Cast action.** `cast` InputMap action: keyboard `Space`, gamepad `A`/cross. When the player presses `cast` in a valid state:
- If `_combo_index == 0` and `_state == READY`: fire chain attack 1, set `_combo_index = 1`, enter CAST_LOCKED, start combo window timer
- If `_combo_index > 0` and `_state == CHAINING` and window is active: fire the next attack, advance `_combo_index`, enter CAST_LOCKED, restart combo window timer
- If all chain attacks fired (index reached `combo_attack_count`): reset chain (`_combo_index = 0`), enter READY — SpellEffect is NOT cleared
- Chain resets to `_combo_index = 0` and READY when the combo window expires

**5. Target selection.** On each cast press, SC&E selects a primary target using the `TargetingModel` for the current attack. The **default targeting model is `DIRECTIONAL_FACING`** — fires a ray from Fayde in `PlayerController.get_facing_direction()` and hits the first enemy whose collision shape intersects the ray within `CAST_MAX_RANGE`. Implemented via `PhysicsDirectSpaceState2D.intersect_ray(origin, origin + facing * range, exclude_list, ENEMY_COLLISION_LAYER)`.

**CAST_MAX_RANGE is per-type.** Ashfire uses `ASHFIRE_MELEE_RANGE = 80px` (melee distance only — enforces the close-in dance identity). All other types use the default `CAST_MAX_RANGE = 150px`. The per-type range is defined in the type's attack data; SC&E reads it alongside the `TargetingModel`.

If `primary_target == null` (no enemy in range/direction): visual cast effect fires in facing direction (minimal Prana-colored particle); no damage or status applied; combo index advances normally.

**Special targeting models** (specified per attack in the Formulas section — override the directional default for that individual attack):
- `SINGLE_NEAREST`: nearest enemy within the type's CAST_MAX_RANGE regardless of facing direction. Used where type-specific descriptions imply auto-targeting (e.g. Voidblue T2 shadow pull on "nearest non-targeted enemy").
- `AREA_AROUND_FAYDE`: all enemies within radius of **Fayde's current position**. Used for Ashfire T3 spinning eruption (80px radius) — the dancer is the origin, not the target. Distinct from `AREA_AT_TARGET`.
- `LINE_THROUGH_TARGET`: hits all enemies within 10px of the line segment from cast origin through primary target, up to `LINE_LENGTH`. Deepfrost T2 second attack.
- `AREA_AT_TARGET`: all enemies within `AoE_radius` of primary target's position. Deepfrost T3 glacial field (120px).
- `ALL_ON_SCREEN`: all active enemies in the arena. Voidblue T3.
- `SELF`: no enemy target; effect applies only to Fayde. Verdant T2.

Retargeting between chain presses: each press re-runs the targeting query at the moment of the press using Fayde's current facing direction and position.

**6. Cast lock and movement interaction.** Immediately after any hit fires, SC&E emits `cast_hit_started(lock_duration)`. Player Controller listens and briefly zeroes movement input for `lock_duration`. Dash input remains available — a dash cancels the cast lock early.

**Per-type cast lock durations:**
- Default: `CAST_LOCK_DURATION = 0.12s`
- Ashfire: `ASHFIRE_CAST_LOCK_DURATION = 0.20s` — longer follow-through for each dance strike; stepping into melee range with a mis-aimed combo has real cost

> **⚠ Player Controller GDD update required**: add `cast_hit_started(duration: float)` signal listener and CAST_LOCKED movement sub-state. CAST_LOCKED: movement input zeroed for duration; dash available and cancels lock.

**7. Damage computation per hit.** For each attack in the chain that lands on a target:

```
Step 1  flat_stat_bonus = aggregate_stat_bonus.get("ASH_DMG" or "FROST_DMG", 0.0)
         (only Ashfire and Deepfrost have flat damage stats; others = 0.0)
Step 2  effective_base = BASE_SPELL_DAMAGE + flat_stat_bonus
Step 3  effective_modifier = spell_effect.base_damage_modifier
         + non_primary_modifiers.get(ASHFIRE).burn_bonus  [0.0 if not active; cap combined at 1.40]
Step 4  raw_damage = effective_base × effective_modifier × tier_attack_modifier
Step 5  IF target is Frozen AND this hit is DIRECT:
            raw_damage *= (1.25 + aggregate_stat_bonus.get("FROST_SHATTER_BONUS", 0.0))
Step 6  IF _followthrough_window > 0 (valid Stormgold interrupt within 1.5s):
            raw_damage *= (1.30 + aggregate_stat_bonus.get("STORM_FOLLOW_DMG", 0.0))
Step 7  IF target is Blinded:
            raw_damage *= (1.0 + aggregate_stat_bonus.get("VOID_DMG_VS_BLIND", 0.0))
Step 8  IF this is the first chain attack AND ASH_CRIT applies:
            ash_crit = aggregate_stat_bonus.get("ASH_CRIT", 0.0)
            IF randf() < ash_crit: raw_damage *= 1.50
Step 9  [Elemental affiliation — FP inline, remove at MVP]
            spell_element = PranaCatalog.get_type(spell_effect.primary_type).damage_class
            IF spell_element != DamageClass.NONE AND target.prana_affiliation == spell_element:
                raw_damage *= 2.0
Step 10 health_and_damage.apply_damage(target, raw_damage, null, DamageSource.DIRECT)
```

`tier_attack_modifier` is looked up from the primary type's tier definition table (Formulas section) using `_combo_index` and `primary_tier`. `randf()` calls use `_rng: RandomNumberGenerator` injected via `@export` for test determinism.

> **⚠ EA&W migration note**: At MVP, remove Step 9 and pass `DamageClass` as the `element` parameter to `apply_damage`. H&D queries EA&W for the multiplier. SC&E stops owning the affiliation check.

**8. Status effect application.** After each hit, SC&E calls `apply_status(target, status_id, effective_duration)` for the primary type's `base_status` and any active non-primary status effects. At FP scope:

| Status | FP behavior |
|--------|-------------|
| `STATUS_FREEZE` | Sets `target.status_freeze_timer = effective_duration`. Enemy AI reads this to freeze movement. Enables Shatter check (Step 5) for subsequent hits. |
| `STATUS_STUN` | Sets `target.status_stun_timer = effective_duration`. Enemy AI reads this to pause movement and attacks. Starts SC&E's `_followthrough_window = 1.5s` for Stormgold Follow-Through (Step 6). |
| `STATUS_BURN` | Sets `target.status_burned = true`. No tick damage at FP — stub only. Status Effects GDD implements ticks at MVP. |
| `STATUS_BLIND` | Sets `target.status_blinded_timer = effective_duration`. Enemy AI miss chance not enforced at FP — stub only. |
| `STATUS_REGEN` | Sets `fayde.status_regen_timer = effective_duration`. No tick healing at FP — stub only. |

Effective durations: Freeze = `2.0 + aggregate_stat_bonus.get("FROST_FREEZE_DUR", 0.0)`. Non-primary Deepfrost Freeze = `1.0 + FROST_FREEZE_DUR` (capped at 2.0). Stun = `0.8 + aggregate_stat_bonus.get("STORM_STUN_DUR", 0.0)`.

**9. Non-primary modifier application.** Applied at chain start (first cast press of the wave):
- **Ashfire NP**: `burn_bonus` carried in `NonPrimaryModifier` → applied in Step 3 per hit
- **Stormgold NP T1**: `_combo_continuation_window += non_primary.window_extension` (0.3s, once at chain start)
- **Stormgold NP T2**: `_final_attack_applies_stun = true` — Stun applied after final chain attack
- **Deepfrost NP T1**: after each chain hit, `apply_status(target, STATUS_CHILL, CHILL_DURATION)` — 15% movement slow for 2.0s; Enemy AI reads to reduce speed
- **Deepfrost NP T2**: first hit applies `STATUS_FREEZE` for `NONPRIMARY_FREEZE_DURATION = 1.0s`; remaining hits apply Chill
- **Verdant NP T1**: on first cast press, `apply_heal(fayde, REGEN_TOTAL)` immediately (6 HP); refreshes if active
- **Verdant NP T2**: as T1 heal; plus `_heal_amplifier = VERDANT_NP_HEAL_AMP (1.25)` — SC&E amplifies all `apply_heal` calls to Fayde during the wave
- **Voidblue NP T1**: on first hit, `if randf() < 0.30: apply_status(target, STATUS_BLIND, 2.0s)`
- **Voidblue NP T2**: Blind is guaranteed on first hit; all currently Blinded enemies get timer extended by 1.0s

**10. Adjacency effect application.** SC&E processes each active adjacency effect from `active_adjacency_effects` once per chain. Three effects require per-frame timers (float accumulator):
- `ADJ_ECHO`: fires a delayed echo strike after `ADJ_ECHO_DELAY = 0.8s`; cancelled on `preparation_started` or any run-ending signal
- `ADJ_BARRIER_HIT`: grants a one-hit absorb barrier on first kill during the chain; listens for `enemy_killed` signal during chain execution
- `ADJ_PHASE_SHIFT`: sets `_cast_invincible = true` for `ADJ_PHASE_DURATION = 0.6s` after cast resolves; H&D queries `SpellCastingEffects.is_cast_invincible() → bool`

**11. Heal amplification (Verdant NP T2).** When `_heal_amplifier > 1.0`: `apply_heal(fayde, (heal_amount + VER_HEAL_FLAT_bonus) × _heal_amplifier)`. Amplifier cleared on `preparation_started`.

**12. No-op SpellEffect handling.** If `combo_resolved` emits with `primary_type = -1`: `push_error()`, do not enter READY state. All cast presses this wave are no-ops.

---

### States and Transitions

| From | To | Trigger |
|------|----|---------|
| `IDLE` | `READY` | `combo_resolved` received during COMBAT_PHASE with valid `primary_type` |
| `READY` | `CAST_LOCKED` | Cast pressed; chain attack 1 fires |
| `CAST_LOCKED` | `CHAINING` | `CAST_LOCK_DURATION` expires; `combo_attack_count > 1` |
| `CAST_LOCKED` | `READY` | `CAST_LOCK_DURATION` expires; final attack in chain just fired |
| `CHAINING` | `CAST_LOCKED` | Cast pressed within window; next attack fires |
| `CHAINING` | `READY` (reset) | `combo_continuation_window` expires; `_combo_index` reset to 0 |
| Any | `IDLE` | `preparation_started`; cache cleared; ADJ_ECHO timers cancelled |

`combat_started` (both `is_boss: false` and `is_boss: true`) sets SC&E ready to receive the SpellEffect. SC&E transitions to READY as soon as `combo_resolved` is received — CR resolves synchronously on the `combat_started` signal.

---

### Interactions with Other Systems

| System | Interaction | Direction |
|--------|-------------|-----------|
| **Combination Resolution** | Listens for `combo_resolved(spell_effect)` to receive the wave payload | CR → SC&E |
| **Game State & Scene Flow** | Listens for `combat_started` and `preparation_started` | Game State → SC&E |
| **Player Controller** | Reads `get_world_position()` and `get_facing_direction()` as cast origin/direction; emits `cast_hit_started(duration)` for brief movement lock | SC&E reads + emits → PC |
| **Health & Damage** | Calls `apply_damage(target, raw_damage, null, DamageSource.DIRECT)` per hit; calls `apply_heal(fayde, amplified_amount)` for Verdant effects | SC&E → H&D |
| **Enemy instances** | Reads `global_position` and `prana_affiliation` for targeting and affiliation check; writes `status_*` fields for FP status stubs | SC&E reads/writes enemy nodes |
| **Audio System** | Calls `play_event(&"sfx_cast_[type_name]")` on each hit; `play_event(&"sfx_cast_miss")` on no-target cast | SC&E → Audio System |
| **Combat HUD** | Exposes `get_cached_spell_effect() → SpellEffect` (read-only); emits `chain_index_changed(combo_index, combo_attack_count)` | Combat HUD → SC&E (read) |
| **Status Effects (MVP)** | Calls `SpellCastingEffects.get_stat_bonus(stat_id)` to query stat bonuses during tick application | Status Effects → SC&E (query) |
| **Elemental Affiliation & Weakness (MVP)** | At MVP: SC&E passes `element` to H&D; H&D queries EA&W. At FP: SC&E applies 2× inline (Step 9 in damage chain) | SC&E → EA&W (at MVP) |

> **⚠ Cross-GDD change flags:**
> 1. **Player Controller GDD** must add: `cast_hit_started(duration: float)` signal listener + CAST_LOCKED movement sub-state
> 2. **Health & Damage GDD** must add: SC&E stat broker reference in Interactions table (`VER_HEAL_FLAT` and status-duration stat bonuses brokered through `SC&E.get_stat_bonus()`)
> 3. **Combination Resolution GDD — Ashfire attack identity revision required**: current attack descriptions ("thrust," "overhead smash," "explosive eruption at target position") must be updated to match the melee dance identity — T1: spinning fire strike; T2: fire palm → sweeping fire kick; T3: fire palm → fire kick → **spinning 360° eruption from Fayde's position** (`AREA_AROUND_FAYDE`, not `AREA_AT_TARGET`)
> 4. **Elemental Affiliation & Weakness** is removed from the FP design order; SC&E owns the 2× check at FP scope

## Formulas

> *`systems-designer` consulted (Lean mode — Formulas is HIGH implementation risk). Rulings applied: Stormgold T3 fork = clean/step-4 only; ASH_CRIT is not primary-type-gated (stat always active); ADJ_DOUBLE_HIT = 0.75× step-4; ADJ_ECHO = 0.50× tier_attack_modifier re-run.*

### Formula 1: BASE_SPELL_DAMAGE

`BASE_SPELL_DAMAGE = 20.0` (tuning knob — SC&E's primary damage dial)

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Spell base damage | `BASE_SPELL_DAMAGE` | float | 10–30 | Reference damage constant for all spell calculations |

**Output range:** 10–30 safe tuning range.
**Reference:** At `BASE_SPELL_DAMAGE = 20`, Ashfire T1 deals `round(20 × 1.25 × 1.00) = 25`. Consistent with H&D worked examples.

---

### Formula 2: Attack Data Table (ATTACK_DATA)

SC&E resolves each chain attack via `ATTACK_DATA[primary_type][primary_tier][attack_index] → AttackData`. Each entry contains: `tier_attack_modifier: float`, `targeting_model: TargetingModel`, `cast_range: float`, `aoe_radius: float`, `secondary_effect` (optional). All values are data-driven Resources — not hardcoded in SC&E logic.

**`TargetingModel` enum:**

| Value | Description |
|-------|-------------|
| `DIRECTIONAL_FACING` | Ray in facing direction; first enemy hit within `cast_range` via `intersect_ray()` |
| `SINGLE_NEAREST` | Nearest enemy within `cast_range` regardless of facing |
| `AREA_AROUND_FAYDE` | All enemies within `aoe_radius` of Fayde's position |
| `AREA_AT_TARGET` | All enemies within `aoe_radius` of primary target's position |
| `LINE_THROUGH_TARGET` | All enemies within 10px of line from Fayde through primary target, up to `cast_range` |
| `ALL_ON_SCREEN` | All active enemies in the arena |
| `SELF` | No enemy target; effect applies to Fayde only |

**Type 0 — Ashfire** (`base_damage_modifier = 1.25`, `cast_range = ASHFIRE_MELEE_RANGE = 80px`, `cast_lock = 0.20s`)

| Tier | Index | `tier_attack_modifier` | `targeting_model` | Notes |
|------|-------|----------------------|-------------------|-------|
| 1 | 0 | 1.00 | DIRECTIONAL_FACING | Spinning fire strike; Burn on hit |
| 2 | 0 | 1.00 | DIRECTIONAL_FACING | Fire palm strike; Burn on hit |
| 2 | 1 | 1.25 | DIRECTIONAL_FACING | Sweeping fire kick; Burn refreshes |
| 3 | 0 | 1.00 | DIRECTIONAL_FACING | Fire palm strike |
| 3 | 1 | 1.25 | DIRECTIONAL_FACING | Sweeping fire kick |
| 3 | 2 | 1.50 | AREA_AROUND_FAYDE (`ASHFIRE_T3_AOE_RADIUS = 80px`) | Spinning 360° eruption; Burn on all hit |

> ⚠ **CR GDD update required**: Ashfire attack descriptions in CR Formulas (thrust/smash/eruption-at-target) must be revised to match this table. T3 eruption is `AREA_AROUND_FAYDE`, not `AREA_AT_TARGET`.

**Worked examples (BASE_SPELL_DAMAGE = 20):**
- T1 neutral: `round(20 × 1.25 × 1.00)` = **25**
- T2 total neutral: 25 + `round(20 × 1.25 × 1.25)` = 25 + **31** = **56**
- T3 eruption neutral per enemy: `round(20 × 1.25 × 1.50)` = **38**
- T1 vs Ashfire-affiliated enemy (2× match): `round(25 × 2.0)` = **50 → clamp to Charger max HP 35** — one-shot

---

**Type 1 — Voidblue** (`base_damage_modifier = 0.90`, `cast_range = 150px`, `cast_lock = 0.12s`)

| Tier | Index | `tier_attack_modifier` | `targeting_model` | Notes |
|------|-------|----------------------|-------------------|-------|
| 1 | 0 | 1.00 | DIRECTIONAL_FACING | Reaching strike; Blind on hit |
| 2 | 0 | 1.00 | DIRECTIONAL_FACING | Strike; Blind on hit |
| 2 | 1 | 1.10 | DIRECTIONAL_FACING | Shadow pull; Stagger (0.3s) on hit; *secondary*: nearest enemy ≠ primary target moved 60px toward Fayde (no damage on pulled enemy) |
| 3 | 0 | 1.00 | DIRECTIONAL_FACING | Strike |
| 3 | 1 | 1.10 | DIRECTIONAL_FACING | Shadow pull (same secondary) |
| 3 | 2 | 1.30 | ALL_ON_SCREEN | Void collapse; Blind on all enemies on screen |

---

**Type 2 — Stormgold** (`base_damage_modifier = 1.15`, `cast_range = 150px`, `cast_lock = 0.12s`)

| Tier | Index | `tier_attack_modifier` | `targeting_model` | Notes |
|------|-------|----------------------|-------------------|-------|
| 1 | 0 | 1.00 | DIRECTIONAL_FACING | Quick snap; Stun (0.8s) on hit; if qualifying interrupt, start `_followthrough_window = 1.5s` |
| 2 | 0 | 1.00 | DIRECTIONAL_FACING | Snap; Stun; `_followthrough_window` as above |
| 2 | 1 | 1.20 | DIRECTIONAL_FACING | Lightning follow; Step 6 bonus if `_followthrough_window > 0` |
| 3 | 0 | 1.00 | DIRECTIONAL_FACING | Snap |
| 3 | 1 | 1.20 | DIRECTIONAL_FACING | Follow |
| 3 | 2 | 1.00 | DIRECTIONAL_FACING | Chain strike (primary); *secondary*: fork to nearest enemy ≠ primary (Formula 4) |

**Qualifying interrupt**: Stun was applied while the enemy's attack animation was active (`enemy._is_attacking == true` at moment of Stun). Idle or moving enemies do not qualify. Enemy AI GDD owns the `_is_attacking` flag.

---

**Type 3 — Deepfrost** (`base_damage_modifier = 0.80`, `cast_range = 150px`, `cast_lock = 0.12s`)

| Tier | Index | `tier_attack_modifier` | `targeting_model` | Notes |
|------|-------|----------------------|-------------------|-------|
| 1 | 0 | 1.00 | DIRECTIONAL_FACING | Push; Freeze (2.0s) on hit |
| 2 | 0 | 1.00 | DIRECTIONAL_FACING | Push; Freeze on hit |
| 2 | 1 | 0.80 | LINE_THROUGH_TARGET (100px) | Frost line; Freeze on all hit |
| 3 | 0 | 1.00 | DIRECTIONAL_FACING | Push |
| 3 | 1 | 0.80 | LINE_THROUGH_TARGET (100px) | Frost line |
| 3 | 2 | 0.00 | AREA_AT_TARGET (`GLACIAL_FIELD_RADIUS = 120px`) | Glacial field; **0 direct damage**; *secondary*: CHILL slow zone for `GLACIAL_FIELD_DURATION = 3.0s`; does not trigger Shatter |

---

**Type 4 — Verdant** (`base_damage_modifier = 0.70`, `cast_range = 150px`, `cast_lock = 0.12s`)

| Tier | Index | `tier_attack_modifier` | `targeting_model` | Notes |
|------|-------|----------------------|-------------------|-------|
| 1 | 0 | 1.00 | DIRECTIONAL_FACING | Bloom strike; Regen applied to Fayde on hit |
| 2 | 0 | 1.00 | DIRECTIONAL_FACING | Bloom strike |
| 2 | 1 | 0.00 | SELF | Shield pulse; **0 damage**; grants one-hit absorb barrier to Fayde (Formula 8) |
| 3 | 0 | 1.00 | DIRECTIONAL_FACING | Bloom strike |
| 3 | 1 | 0.00 | SELF | Shield pulse (barrier) |
| 3 | 2 | 1.20 | DIRECTIONAL_FACING | Rejuvenating strike; Regen resets to 3.0s + immediate 2 HP tick on hit |

---

### Formula 3: Per-Hit Damage Chain

Complete per-hit computation for any attack where `primary_target != null` AND `tier_attack_modifier > 0.0`:

```gdscript
# Step 1 — flat stat bonus (type-conditional branch)
if   primary_type == 0: flat_stat_bonus = aggregate_stat_bonus.get(&"ASH_DMG",   0.0)
elif primary_type == 3: flat_stat_bonus = aggregate_stat_bonus.get(&"FROST_DMG", 0.0)
else:                   flat_stat_bonus = 0.0

# Step 2
effective_base = BASE_SPELL_DAMAGE + flat_stat_bonus

# Step 3 — type modifier + Ashfire NP burn bonus
burn_bonus = ashfire_np_modifier.burn_bonus if ashfire_np_active else 0.0
effective_modifier = clamp(base_damage_modifier + burn_bonus, 0.0, 1.40)

# Step 4 — core damage
raw_damage = effective_base * effective_modifier * tier_attack_modifier

# Step 5 — Shatter (Frozen target)
if target.has_status(STATUS_FREEZE):
    raw_damage *= (1.25 + aggregate_stat_bonus.get(&"FROST_SHATTER_BONUS", 0.0))

# Step 6 — Stormgold Follow-Through
if _followthrough_window > 0.0:
    raw_damage *= (1.30 + aggregate_stat_bonus.get(&"STORM_FOLLOW_DMG", 0.0))

# Step 7 — Blind bonus
if target.has_status(STATUS_BLIND):
    raw_damage *= (1.0 + aggregate_stat_bonus.get(&"VOID_DMG_VS_BLIND", 0.0))

# Step 8 — ASH_CRIT (first chain attack only; any primary type)
if _combo_index == 0:
    ash_crit = aggregate_stat_bonus.get(&"ASH_CRIT", 0.0)
    if ash_crit > 0.0 and _rng.randf() < ash_crit:
        raw_damage *= 1.50

# Step 9 — Elemental affiliation [FP inline — remove at MVP]
var spell_element = PranaCatalog.get_type(primary_type).damage_class
if spell_element != DamageClass.NONE and target.prana_affiliation == spell_element:
    raw_damage *= 2.0

# Step 10
health_and_damage.apply_damage(target, raw_damage, null, DamageSource.DIRECT)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `BASE_SPELL_DAMAGE` | float | 10–30 | SC&E tuning constant (Formula 1) |
| `flat_stat_bonus` | float | 0.0–15.0 | Type-conditional; lv.1 max: ASH_DMG = 5, FROST_DMG = 3 |
| `effective_modifier` | float | 0.70–1.40 | Capped; primary type modifier + optional Ashfire NP burn bonus |
| `tier_attack_modifier` | float | 0.00–1.50 | From Formula 2 ATTACK_DATA table |
| `raw_damage` | float | 0–unbounded | Passed to H&D; H&D applies `clamp(round(raw_damage), 0, target_max_hp)` |

**Steps 5–8 are independent multipliers applied in fixed sequential order** — consistent with CR Formula 5 spec. All four can co-occur on a single hit.

**Output range:** Practical maximum at FP (Ashfire T3, match + Shatter + Crit, no stat bonuses): `round(20 × 1.25 × 1.50 × 1.25 × 1.50 × 2.0)` = 141 → clamped to target_max_hp. High ceiling is intentional — payoff for stacking Ashfire in melee range against a matched, Frozen enemy.

---

### Formula 4: Stormgold T3 Fork Damage (Clean Fork)

Fork hits the nearest enemy ≠ primary target. **Step-4 only** — Steps 5–9 do not propagate.

`fork_damage = effective_base × effective_modifier × 1.00 × 0.60`

`effective_base` and `effective_modifier` are the same values computed in Steps 1–3 for this attack — not re-computed.

```gdscript
fork_target = find_nearest_enemy_excluding(primary_target)
if fork_target == null: fork_target = primary_target  # only one enemy present
health_and_damage.apply_damage(fork_target, fork_damage, null, DamageSource.DIRECT)
# No status applied to fork target
```

| Variable | Type | Description |
|----------|------|-------------|
| `fork_scalar` | float (0.60) | Fixed fork fraction |
| `effective_base`, `effective_modifier` | float | From Steps 1–3 of the third attack |

**Output:** `round(20 × 1.15 × 1.00 × 0.60)` = `round(13.8)` = **14** fork damage (neutral, no bonuses).

---

### Formula 5: ADJ_DOUBLE_HIT Second Firing

**Step-4 only** for the second firing. Steps 5–9 do not apply. Status applies on both firings (refresh).

`double_hit_damage = effective_base × effective_modifier × tier_attack_modifier × 0.75`

`effective_base`, `effective_modifier`, and `tier_attack_modifier` are the same values used in Step 4 of this attack.

```gdscript
health_and_damage.apply_damage(same_target, double_hit_damage, null, DamageSource.DIRECT)
apply_status(same_target, base_status, effective_status_duration)  # refresh
```

**Output:** At T1 Ashfire: `round(20 × 1.25 × 1.00 × 0.75)` = `round(18.75)` = **19**.

---

### Formula 6: ADJ_ECHO Strike

Fires `ADJ_ECHO_DELAY = 0.8s` after full chain resolves. Re-runs Steps 1–3 at echo fire time (fresh `aggregate_stat_bonus`). Uses first attack's `tier_attack_modifier` (= 1.00 for all types). Steps 5–9 do not apply. Primary `base_status` applies on hit.

`echo_damage = effective_base × base_damage_modifier × 1.00 × 0.50`

(Simplifies to `effective_base × base_damage_modifier × 0.50` since all type first-attack modifiers are 1.00.)

Target selection: re-runs `DIRECTIONAL_FACING` query at Fayde's position at echo fire time. If no target: echo misses visually, 0 damage.

**Output:** At T1 Ashfire (no stat bonus): `round(20 × 1.25 × 0.50)` = `round(12.5)` = **13**.

---

### Formula 7: Status Effective Durations

SC&E computes these before each `apply_status()` call:

| Status | Formula | Default |
|--------|---------|---------|
| Primary Freeze | `2.0 + aggregate_stat_bonus.get(&"FROST_FREEZE_DUR", 0.0)` | 2.0s |
| Non-primary Deepfrost Freeze | `min(1.0 + aggregate_stat_bonus.get(&"FROST_FREEZE_DUR", 0.0), 2.0)` | 1.0s |
| Stun | `0.8 + aggregate_stat_bonus.get(&"STORM_STUN_DUR", 0.0)` | 0.8s |
| Blind | `2.0 + aggregate_stat_bonus.get(&"VOID_BLIND_DUR", 0.0)` | 2.0s |
| Stagger (Voidblue T2) | `0.3 + aggregate_stat_bonus.get(&"VOID_STAGGER_DUR", 0.0)` | 0.3s |
| Regen | `3.0` (constant from Prana Data) | 3.0s |
| Chill | `CHILL_DURATION = 2.0s` (constant) | 2.0s |
| ADJ_PHASE_SHIFT | `ADJ_PHASE_DURATION = 0.6s` (constant) | 0.6s |

**ADJ_STATUS_EXTEND**: if active, adds `ADJ_STATUS_EXT = 1.0s` to the primary status duration on the primary target only (additive to the formula above).

---

### Formula 8: Verdant Barrier HP

`barrier_hp = round(BASE_SPELL_DAMAGE × base_damage_modifier × BARRIER_COEFFICIENT)`
`             + aggregate_stat_bonus.get(&"VER_BARRIER_HP", 0.0)`

| Variable | Default | Description |
|----------|---------|-------------|
| `BARRIER_COEFFICIENT` | 0.10 | Tuning knob |
| `VER_BARRIER_HP` stat | +3 HP at lv.1 | Additive bonus from Verdant stat pool |

**Output:** `round(20 × 0.70 × 0.10)` = `round(1.4)` = **1 HP** base multi-hit pool. Single-hit immunity is always full regardless of pool size (absorbs entire next single hit). Pool governs multi-hit tick depletion only — per CR Formula 5 spec.

## Edge Cases

> *Specialist agents not consulted — Lean mode.*

- **If `primary_target == null` (no enemy in ray):** Visual cast effect fires in facing direction; no damage, no status; `_combo_index` advances normally; combo window timer starts. Chain does not reset on a miss.

- **If `tier_attack_modifier == 0.0` (Verdant T2/T3 SELF attacks, Deepfrost T3 glacial field):** SC&E skips Formula 3 entirely. Only the secondary effect fires (barrier grant or glacial slow zone). `apply_damage` is not called with 0 — the zero-modifier check guards this explicitly before entering the damage chain.

- **If `SELF` targeting fires but Fayde is dead:** No effect applied. H&D's dead-target guard handles any `apply_heal` call; SC&E skips the barrier grant if `fayde.current_hp <= 0`.

- **If `ALL_ON_SCREEN` (Voidblue T3) fires with 0 active enemies:** No hits, no signals. Chain index advances normally. No error.

- **If `combo_resolved` fires while SC&E is already in CHAINING state** (abnormal — second wave started mid-chain): `push_error()`, discard the new SpellEffect. The in-progress chain finishes with the current cache. `preparation_started` must fire before the next combat to clear state.

- **If `preparation_started` fires while `_combo_index > 0`:** Chain resets immediately — `_combo_index = 0`, cache cleared, all float accumulator timers (follow-through window, echo delay, phase shift) zeroed. No echo fires into the preparation phase.

- **If ADJ_ECHO delay elapses after `preparation_started`:** Echo is cancelled when `preparation_started` is received — timer zeroed. SC&E additionally guards the echo fire callback with `if _state != IDLE` before executing. Stale echoes are discarded.

- **If ADJ_DOUBLE_HIT and ADJ_EXTRA_HIT are both active:** Both apply. Sequence: standard chain → first attack fires twice in-place (Double Hit; second firing is step-4 only) → bonus attack appended at end (Extra Hit at `0.80×` final attack modifier). Consistent with CR Edge Case specification.

- **If multiple hit-detection queries (`AREA_AROUND_FAYDE`, `LINE_THROUGH_TARGET`, or triggered adjacency secondary effects) could reach the same enemy in one attack resolution:** SC&E deduplicates the target list before issuing `apply_damage` calls. Each enemy is hit at most once per attack resolution from the same effect source.

- **If `_followthrough_window` expires between chain press 1 and press 2:** Step 6 bonus does not apply to the second attack. The window is checked at hit resolution time, not at input time.

- **If Stormgold T3 fork finds no eligible second enemy:** Fork hits the primary target for `0.60×` as a bonus hit (per CR T3 spec). Not a miss — always fires.

- **If Verdant T3 rejuvenating strike fires while `_heal_amplifier > 1.0` (Verdant NP T2) is active:** The amplifier applies to the immediate 2 HP tick: `round(2 × VERDANT_NP_HEAL_AMP)` = 3 HP at default. Consistent with CR: "all healing Fayde receives during the active Regen window is amplified."

- **If Ashfire T3 eruption (`AREA_AROUND_FAYDE`) fires with no enemies within 80px:** No hits, no Burn applications. Visual eruption fires (minimal VFX). Chain resets to READY.

- **If `ASH_CRIT` is in `aggregate_stat_bonus` and `_combo_index > 0`:** No crit roll. Step 8 is strictly guarded by `_combo_index == 0`. Stat is present but not read after the first attack.

- **If Stormgold T3 fork target and `ADJ_CHAIN_LIGHTNING` arc target resolve to the same enemy:** Both effects issue separate `apply_damage` calls. H&D's dead-target guard handles the second call if the first killed the enemy. This is not an error.

## Dependencies

### Systems This System Depends On

| # | System | What SC&E needs | Dependency type |
|---|--------|----------------|----------------|
| 1 | **Combination Resolution (#2)** | `combo_resolved(spell_effect)` signal — the wave payload | Hard |
| 2 | **Player Controller (#5)** | `get_world_position()`, `get_facing_direction()` as cast origin/direction | Hard |
| 3 | **Health & Damage (#6)** | `apply_damage(target, raw_damage, null, DamageSource.DIRECT)` and `apply_heal(fayde, amount)` | Hard |
| 4 | **Game State & Scene Flow (#27)** | `combat_started`, `preparation_started` signals | Hard |
| 5 | **Prana Data (#4)** | `PranaCatalog.get_type(id).damage_class` for elemental affiliation inline check | Hard (FP) |
| 6 | **Enemy instances** | `global_position`, `prana_affiliation`, `status_*` fields, `_is_attacking` flag | Hard |
| 7 | **Audio System (#29)** | `play_event(&"sfx_cast_[type_name]")`, `play_event(&"sfx_cast_miss")` | Soft (graceful no-op if absent) |

### Systems That Depend On SC&E

| System | What it needs | Bidirectional contract |
|--------|--------------|----------------------|
| **Elemental Affiliation & Weakness (#10)** | At MVP: SC&E passes element parameter to H&D; EA&W defines the multiplier interface. At FP: EA&W is removed from scope — SC&E inlines the 2× check | EA&W GDD must note SC&E as the caller at MVP |
| **Status Effects (#7, MVP)** | `SpellCastingEffects.get_stat_bonus(stat_id: StringName) → float` — queries SC&E for status-modifying stat bonuses during tick application | Status Effects GDD must list SC&E as its stat source |
| **Combat HUD (#22)** | `get_cached_spell_effect() → SpellEffect` (read-only); `chain_index_changed(combo_index, combo_attack_count)` signal for chain progress display | Combat HUD GDD must list SC&E as source for chain display data |
| **Wave / Encounter System (#12)** | Indirectly — SC&E's `apply_damage` calls trigger `enemy_killed` in H&D, which Wave System listens to. No direct SC&E dependency. | H&D is the intermediary |

**Bidirectionality cross-checks:**
- Combination Resolution GDD lists SC&E as a downstream dependent ✓
- **Player Controller GDD update required** ⚠: add SC&E as dependent system; add `cast_hit_started(duration: float)` signal listener; add CAST_LOCKED movement sub-state
- **Health & Damage GDD update required** ⚠: add SC&E as a calling system in the Interactions table; note that `VER_HEAL_FLAT` and status-duration stat bonuses are brokered through `SC&E.get_stat_bonus()`

## Tuning Knobs

| Knob | Symbol | Default | Safe Range | Effect if too high | Effect if too low |
|------|--------|---------|------------|-------------------|-------------------|
| Spell base damage | `BASE_SPELL_DAMAGE` | 20.0 | 10–30 | All spells overkill; low-tier combos trivialize enemies | All spells feel weak; T3 fails to one-shot Clusters (12 HP) |
| Default cast range | `CAST_MAX_RANGE` | 150px | 80–250px | Fayde hits from across the arena; positioning irrelevant | Requires nearly adjacent contact for all non-Ashfire types |
| Ashfire melee range | `ASHFIRE_MELEE_RANGE` | 80px | 48–120px | Ashfire becomes safe-range; loses dance identity | Fayde must be inside enemy hitbox; collision issues |
| Default cast lock duration | `CAST_LOCK_DURATION` | 0.12s | 0.05–0.25s | Noticeable movement pause per hit; combo feels sluggish | No perceivable commitment; cast lock has no feel |
| Ashfire cast lock duration | `ASHFIRE_CAST_LOCK_DURATION` | 0.20s | 0.12–0.35s | Dance combo feels heavy (correct) vs clunky | Ashfire feels identical to other types; dance identity lost |
| Combo continuation window | `combo_continuation_window` | 2.0s | 0.8–3.0s | Chain timing has no skill expression | Too tight for age 7+ target; T3 chains rarely complete |
| Ashfire T3 eruption radius | `ASHFIRE_T3_AOE_RADIUS` | 80px | 40–150px | Eruption clears full waves without positioning | AoE barely clips secondary targets; loses wave-clear payoff |
| Glacial field radius | `GLACIAL_FIELD_RADIUS` | 120px | 60–200px | Deepfrost T3 trivializes approach lanes | Zone too small; positional value lost |
| Glacial field duration | `GLACIAL_FIELD_DURATION` | 3.0s | 1.5–5.0s | Arena permanently slowed; no recovery opportunity | Zone expires before enemies can be driven into it |
| Follow-Through window | `FOLLOWTHROUGH_WINDOW` | 1.5s | 0.5–2.5s | Bonus feels automatic; interrupt skill has no expression | Window too tight; qualifying interrupts rarely land the bonus |
| ADJ_ECHO delay | `ADJ_ECHO_DELAY` | 0.8s | 0.3–2.0s | Echo reads as a 4th chain attack at short delays | Too late; echo catches only stationary enemies |
| ADJ_PHASE_SHIFT duration | `ADJ_PHASE_DURATION` | 0.6s | 0.3–1.0s | Post-cast invincibility trivializes melee responses | Too short to protect against contact-damage enemies at Ashfire range |
| Verdant barrier coefficient | `BARRIER_COEFFICIENT` | 0.10 | 0.05–0.30 | Barrier HP pool absorbs many rapid ticks | Multi-hit pool depletes in one rapid tick sequence |
| Voidblue shadow pull distance | `PULL_DISTANCE` | 60px | 20–100px | Pulled enemy snaps to Fayde's position; unnatural | Pull imperceptible; secondary effect has no gameplay value |
| Chill slow percentage | `CHILL_SLOW_PCT` | 0.15 | 0.05–0.40 | Chill approaches Freeze-level slow | Too minor to notice; feels cosmetic |
| Chill duration | `CHILL_DURATION` | 2.0s | 1.0–3.0s | Persists long past tactical relevance | Expires before capitalizing on slowed movement |

**Interaction warnings:**
- `STORMGOLD_NP_WINDOW_T1`, `ADJ_COMBO_WIN`, and `STORM_COMBO_SPD` stat all stack additively on `combo_continuation_window`. Add a `COMBO_WINDOW_MAX` safety cap if playtest reveals excessive tolerance.
- `ASHFIRE_MELEE_RANGE` must always be < `CAST_MAX_RANGE`. Setter should enforce this — if equal, Ashfire loses its short-range identity.
- `ASHFIRE_CAST_LOCK_DURATION` must always be > `CAST_LOCK_DURATION`. Setter should enforce this — Ashfire's dance commitment must exceed the default.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

> *`qa-lead` consulted (Lean mode — Acceptance Criteria is HIGH implementation risk). 25 criteria: 23 [U] unit tests, 2 [M] manual QA (physics-dependent). Coverage: all Section C core rules + all Section D formulas + key edge cases.*

Classification: **[U]** = Unit test (GUT, headless) | **[I]** = Integration | **[M]** = Manual QA (requires physics scene)

**Test harness requirements**: Inject `_rng: RandomNumberGenerator` via `@export` — seed it in `before_each()` for deterministic crit/miss rolls. Audio System injectable via `@export var audio_system`. Drive float accumulator timers by calling `_process(1.0 / 60.0)` repeatedly.

---

### State Machine & Lifecycle

**[U] AC-SC-01** — READY state entered on `combo_resolved` during COMBAT_PHASE
GIVEN SC&E is in IDLE state,
WHEN `_on_combo_resolved(spell_effect)` is called with `spell_effect.primary_type = 0` during COMBAT_PHASE,
THEN `_state == READY` and `_combo_index == 0`.

**[U] AC-SC-02** — Cast input rejected when state is IDLE
GIVEN SC&E is in IDLE state with no cached SpellEffect,
WHEN `cast` action fires (simulated),
THEN `apply_damage` is never called and `_combo_index` remains 0.

**[U] AC-SC-03** — Cast input rejected when `_cast_lock_timer > 0`
GIVEN SC&E is in READY state with a valid SpellEffect and `_cast_lock_timer = 0.05`,
WHEN `cast` action fires,
THEN no attack is issued and `_combo_index` remains 0.

**[U] AC-SC-04** — `_combo_index` advances on each cast press within window
GIVEN a Deepfrost T3 SpellEffect (combo_attack_count = 3) cached, SC&E in READY state,
WHEN cast fires; cast lock expires (via `_process(0.13)`); cast fires again,
THEN `_combo_index == 2` after the second press.

**[U] AC-SC-05** — Chain resets to READY when `combo_continuation_window` expires
GIVEN SC&E is in CHAINING state with `_combo_index = 1` and `combo_continuation_window = 2.0s`,
WHEN `_process(delta)` is called with cumulative delta ≥ 2.0s without a cast press,
THEN `_combo_index == 0` and `_state == READY`.

**[U] AC-SC-06** — `preparation_started` resets to IDLE and clears cache
GIVEN SC&E is in CHAINING state (`_combo_index = 1`) with a non-null `_current_spell_effect`,
WHEN `_on_preparation_started()` is called,
THEN `_state == IDLE`, `_combo_index == 0`, and `_current_spell_effect == null`.

---

### Targeting

**[M] AC-SC-07** — DIRECTIONAL_FACING selects first enemy in ray within CAST_MAX_RANGE
GIVEN Fayde at (100, 100) facing right (+X), enemy A at (180, 100) (80px away), enemy B at (230, 100) (130px away), `CAST_MAX_RANGE = 150px`,
WHEN a Voidblue T1 cast fires,
THEN `apply_damage` is called on enemy A only; enemy B receives no damage.

**[U] AC-SC-08** — No-target cast: combo advances, no damage or status
GIVEN SC&E in READY state with an Ashfire T1 SpellEffect, `primary_target == null` (ray finds no collision),
WHEN cast fires,
THEN `apply_damage` is never called, `apply_status` is never called, and `_combo_index == 1`.

**[M] AC-SC-09** — Ashfire T3 eruption uses `AREA_AROUND_FAYDE`, not `AREA_AT_TARGET`
GIVEN Fayde at (200, 200), enemy A at (240, 200) (40px from Fayde), enemy B at (320, 200) (120px from Fayde — outside `ASHFIRE_T3_AOE_RADIUS = 80px`),
WHEN Ashfire T3 attack index 2 fires,
THEN `apply_damage` is called on enemy A; enemy B receives no damage.

---

### Cast Lock

**[U] AC-SC-10** — Cast lock duration: 0.12s default; 0.20s for Ashfire
GIVEN two separate test cases — one with a Voidblue T1 SpellEffect (default lock), one with an Ashfire T1 SpellEffect,
WHEN each fires a cast,
THEN the Voidblue case emits `cast_hit_started` with `lock_duration == 0.12`; the Ashfire case emits `cast_hit_started` with `lock_duration == 0.20`.

---

### Follow-Through Gate

**[U] AC-SC-11** — Stormgold Follow-Through: Step 6 suppressed when `_followthrough_window == 0`
GIVEN a Stormgold T2 SpellEffect (base_damage_modifier = 1.15, tier[2][1].modifier = 1.20), no stat bonuses, no Frozen/Blind conditions, `_followthrough_window = 0.0`,
WHEN Stormgold T2 index 1 fires,
THEN `apply_damage` is called with `raw_damage = round(20 × 1.15 × 1.20) = 28` (no ×1.30 Step 6 bonus).

---

### Damage Formulas

**[U] AC-SC-12** — Formula 1: Ashfire T1 neutral = 25
GIVEN `BASE_SPELL_DAMAGE = 20.0`, `aggregate_stat_bonus` empty, no status conditions, Ashfire T1 SpellEffect (`base_damage_modifier = 1.25`, `tier_attack_modifier = 1.00`),
WHEN cast fires at index 0,
THEN `apply_damage` is called with `raw_damage = 25.0`.

**[U] AC-SC-13** — Formula 3 Step 1: type branch reads correct stat key
GIVEN `aggregate_stat_bonus = {"ASH_DMG": 5.0, "FROST_DMG": 3.0}`:
(a) primary_type = 0 → `flat_stat_bonus = 5.0`;
(b) primary_type = 3 → `flat_stat_bonus = 3.0`;
(c) primary_type = 2 → `flat_stat_bonus = 0.0`.
All three sub-cases must pass. The `or`-operator bug (reading `"ASH_DMG"` for all types) fails case (c).

**[U] AC-SC-14** — Formula 3 Step 5: Shatter multiplies raw_damage on Frozen target
GIVEN Deepfrost T1 SpellEffect (`base_damage_modifier = 0.80`, `tier_attack_modifier = 1.00`), no stat bonuses, target has `STATUS_FREEZE`,
WHEN cast fires,
THEN `apply_damage` is called with `raw_damage = round(20 × 0.80 × 1.00 × 1.25) = 20`.

**[U] AC-SC-15** — Formula 3 Step 9: Elemental affiliation doubles damage
GIVEN Ashfire T1 SpellEffect (base_damage_modifier = 1.25, tier_attack_modifier = 1.00), no stat bonuses, no status conditions, `target.prana_affiliation == DamageClass.FIRE` (matches Ashfire element),
WHEN cast fires at index 0,
THEN `apply_damage` is called with `raw_damage = round(25.0 × 2.0) = 50`.

**[U] AC-SC-16** — Formula 4: Stormgold T3 fork = step-4 × 0.60; Steps 5–9 excluded
GIVEN Stormgold T3 SpellEffect (base_damage_modifier = 1.15, no stat bonuses), two distinct enemies present,
WHEN the third chain attack (index 2) fires,
THEN `apply_damage` on fork target is called with `raw_damage = round(20 × 1.15 × 1.00 × 0.60) = 14`; no Shatter/Follow-Through/Affiliation multipliers apply to the fork call.

**[U] AC-SC-17** — Formula 5: ADJ_DOUBLE_HIT second firing = step-4 × 0.75; Shatter excluded from second firing
GIVEN ADJ_DOUBLE_HIT active, Ashfire T1 SpellEffect (base_damage_modifier = 1.25, tier_attack_modifier = 1.00), Frozen target (would trigger Shatter),
WHEN cast fires at index 0,
THEN `apply_damage` is called twice on the same target: first call with `raw_damage ≈ 31.25` (step 4 × Shatter: 20 × 1.25 × 1.00 × 1.25); second call with `raw_damage ≈ 18.75` (step 4 × 0.75 only: 20 × 1.25 × 1.00 × 0.75; no Shatter on second firing).

**[U] AC-SC-18** — Formula 6: ADJ_ECHO fires at 0.8s; scalar = base_damage_modifier × 0.50
GIVEN ADJ_ECHO active, Ashfire T1 SpellEffect (base_damage_modifier = 1.25, no stat bonuses), full chain resolved, `_rng` seeded to never crit,
WHEN `_process(delta)` called with cumulative delta = 0.8s after chain end,
THEN `apply_damage` is called on the echo target with `raw_damage = round(20 × 1.25 × 0.50) = 13`; no Steps 5–9 multipliers applied.

**[U] AC-SC-19** — Formula 7: status durations at default (no stat bonuses)
GIVEN Deepfrost T1 SpellEffect with `aggregate_stat_bonus` empty,
WHEN cast fires on a valid target,
THEN `target.status_freeze_timer == 2.0`.
GIVEN Stormgold T1 SpellEffect with empty bonuses,
WHEN cast fires,
THEN `target.status_stun_timer == 0.8`.

---

### Edge Cases

**[U] AC-SC-20** — `tier_attack_modifier == 0.0` suppresses `apply_damage` call
GIVEN (a) Verdant T2 SpellEffect, cast advances to index 1 (SELF, modifier = 0.00);
GIVEN (b) Deepfrost T3 SpellEffect, cast advances to index 2 (glacial field, modifier = 0.00),
WHEN each fires,
THEN `apply_damage` is never called for those attacks in either case.

**[U] AC-SC-21** — `preparation_started` mid-chain cancels echo timer
GIVEN ADJ_ECHO active, full chain resolved, `_echo_timer` at 0.4s elapsed (0.4s remaining),
WHEN `_on_preparation_started()` is called,
THEN `_echo_timer == 0.0`, `_state == IDLE`.

**[U] AC-SC-22** — ADJ_ECHO does not fire after `preparation_started` even when delay elapses
GIVEN AC-SC-21 state — `preparation_started` already received,
WHEN `_process(delta)` continues until total elapsed > 0.8s,
THEN `apply_damage` is never called for the echo.

**[U] AC-SC-23** — ASH_CRIT applies at `_combo_index == 0` only; suppressed at index 1+
GIVEN `aggregate_stat_bonus = {"ASH_CRIT": 1.0}` (guaranteed crit), `_rng.randf()` always returns 0.0, Stormgold T2 SpellEffect (combo_attack_count = 2),
WHEN cast fires at index 0: `apply_damage` raw_damage includes ×1.50 crit multiplier;
WHEN cast lock expires and cast fires at index 1: `apply_damage` raw_damage does NOT include ×1.50 (Step 8 guard skipped entirely at `_combo_index > 0`).

**[U] AC-SC-24** — `combo_resolved` with `primary_type == -1` does not enter READY
GIVEN SC&E in IDLE,
WHEN `_on_combo_resolved(spell_effect)` is called with `spell_effect.primary_type == -1`,
THEN `_state == IDLE`, `push_error` was called, and any subsequent cast press produces no attack.

**[U] AC-SC-25** — Formula 7 with stat bonuses: Freeze = 2.0 + bonus; Stun = 0.8 + bonus
GIVEN `aggregate_stat_bonus = {"FROST_FREEZE_DUR": 0.5, "STORM_STUN_DUR": 0.4}` and a Deepfrost T1 SpellEffect,
WHEN cast fires,
THEN `target.status_freeze_timer == 2.5`.
GIVEN same bonuses and Stormgold T1 SpellEffect,
WHEN cast fires,
THEN `target.status_stun_timer == 1.2`.

---

*Coverage: AC-SC-01–06 = Core Rules 1–6 (state machine); AC-SC-07–09 = Rule 6–9 (targeting); AC-SC-10 = Rule 8 (cast lock); AC-SC-11 = Rule 10 (Follow-Through gate); AC-SC-12 = Formula 1; AC-SC-13 = Formula 3 Step 1 type branch; AC-SC-14 = Formula 3 Step 5 (Shatter); AC-SC-15 = Formula 3 Step 9 (affiliation); AC-SC-16 = Formula 4 (fork); AC-SC-17 = Formula 5 (ADJ_DOUBLE_HIT); AC-SC-18 = Formula 6 (ADJ_ECHO); AC-SC-19, AC-SC-25 = Formula 7 (status durations); AC-SC-20–22 = tier_modifier==0 + echo cancellation edge cases; AC-SC-23 = Rule 11 (ASH_CRIT gate); AC-SC-24 = Rule 12 (no-op SpellEffect).*

## Open Questions

[To be designed]
