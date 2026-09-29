# Bullet Hell Layer

> **Status**: Approved (2026-09-24) · **ADR**: ADR-0018 · **Owner**: solo dev

## 1. Overview

Enemies attack with data-driven bullet patterns: fans, rings, rotating spirals, sine
waves, slow homing shots, telegraphed lasers and mortar blasts. The duo has a tiny
hurtbox, earns Special meter by grazing bullets, wipes bullets with Perfect Casts and
Specials, and dashes twice in a row. Rooms send reinforcements mid-fight, some enemies
spawn as elites, and bosses add a pattern layer at each HP phase.

## 2. Player Fantasy

Threading a needle through a screen of light and answering with a perfectly timed
spell that erases it. Danger is dense but always readable: every volley glows before it
fires, lasers show their line, mortars show where they land, and the active brother's hurtbox is a
visible white dot.

## 3. Detailed Rules

1. **Pattern layers.** Each `EnemyType` lists `pattern_layers`. A layer fires every
   `interval` s after `initial_delay`, as `bursts` volleys spaced `burst_interval` apart.
   The enemy glows in the pattern colour for `windup_sec` before each firing.
2. **Shapes.** AIMED re-aims at the duo every volley. FAN locks aim at the start of a
   firing and spreads `count` bullets over `spread_deg`. RING spreads `count` over 360°.
   SPIRAL is a ring rotated `spin_deg` more on every volley, across firings.
3. **Motion.** STRAIGHT; SINE (weaves ±`sine_amplitude` px at `sine_frequency` Hz);
   HOMING (turns ≤ `homing_turn_deg`/s toward the active brother for `homing_duration` s, then straight).
4. **Hazards.** LASER: a warning line tracks the duo for 70 % of `telegraph_sec`, locks,
   then the beam is live for `active_sec`. MORTAR: a closing ring marks the active brother's position
   for `telegraph_sec`, then blasts `radius` px and releases `splash_count` bullets.
5. **Hurtbox.** A bullet hits when its centre is within `bullet_radius + player_hurt_radius`
   of the duo. Bullet damage uses the CONTACT source, so dash i-frames and post-hit grace apply.
6. **Graze.** A bullet (or beam / blast edge) passing within `bullet_radius + graze_radius`
   without hitting adds `graze_meter_gain` Special meter, once per bullet. Dashing
   through a bullet doesn't consume it and grazes for `× dash_graze_mult`.
7. **Bullet cancel.** A Perfect Cast clears bullets within `perfect_cancel_radius` of
   The duo. The Special clears bullets within its radius × `special_cancel_radius_mult`
   (Lightning chain: `special_cancel_fallback_radius`). A cleared wave and every new
   preparation phase clear all enemy fire.
8. **Dash charges.** The duo holds `dash_charges` charges (shared; only Faith can spend them, ADR-0058). Each dash spends one; one
   charge recharges every `dash_recharge_sec` (× dash-cooldown sigils) until full.
9. **Elites.** Each non-boss spawn rolls `elite_chance` (+ `elite_room_bonus` in ELITE
   rooms). Elites get `× elite_hp_mult` HP, `× elite_damage_mult` damage,
   `× elite_scale_mult` size, a golden aura and the `elite_pattern` layer.
10. **Reinforcements.** The wave is split into `reinforcement_groups` groups. Group 0
    spawns at combat start; the next arrives, at the markers farthest from the active brother and
    after a `reinforcement_warning_sec` warning ring, when `reinforcement_trigger_alive`
    or fewer enemies remain. The wave clears when every group has spawned and died.
11. **Boss phases.** Boss layers with `hp_threshold < 1` switch on below that HP ratio.
    Each new layer triggers a flash, a camera shake and a "PHASE n" callout.

### New enemies

| ID | Name | Archetype | Attack |
|----|------|-----------|--------|
| 6 | Spinner | Shooter | 3-arm rotating spiral, constant stream |
| 7 | Sniper | Shooter | Telegraphed laser, long range |
| 8 | Mortar | Shooter | 3 shells trailing the duo, each with a 6-bullet splash |
| 9 | Weaver | Swarmer | 5-bullet sine-wave fan while orbiting |
| 10 | Splitter | Seeker | Bursts into a 10-bullet ring when killed |

Rifter now fires a 3-bullet fan twice per cycle. Both bosses add a slow 4-arm spiral
below 66 % HP, then mortar rain and an accelerating triple ring wall below 33 %.

## 4. Formulas

- Bullet damage `D = base_damage × damage_mult` (elites: `× elite_damage_mult`).
- Volley angles: FAN `θᵢ = aim − s/2 + i·s/(n−1)`; RING/SPIRAL `θᵢ = aim + spin·v + i·2π/n`,
  where `s` = spread (rad), `n` = count, `v` = volleys fired so far.
- Volley speed `vₖ = speed + speed_step × k` for volley `k` of a firing.
- Hit: `|bullet − the duo| ≤ r_b + r_hurt`; graze: `≤ r_b + r_graze`.
- Meter per graze `G = graze_meter_gain × (dash_graze_mult if dashing else 1)`.
- Elite HP `= round(base_hp × elite_hp_mult)`.

## 5. Edge Cases

- Last enemy is a Splitter: its death ring spawns, then the deferred wave-clear wipes it.
- A reinforcement group that spawns nothing (no scene) pulls the next group at once.
- Stunned enemies do not tick patterns; preparation resets every runner.
- A SHOOTER with no pattern layers keeps the legacy single aimed shot.
- A pooled bullet is hidden immediately on hit and released deferred, so it never
  changes physics state during a collision callback.
- Bosses can never be elites.

## 6. Dependencies

Enemy Data (`pattern_layers`), Enemy AI (archetype movement), Wave Encounter System
(groups, elites, clear), Player Controller (dash charges, hurtbox dot), Special Attack
(meter, Perfect Cast and Special signals), Health & Damage (`register_enemy hp_mult`),
Combat HUD (phase callout).

## 7. Tuning Knobs

`assets/data/bullet_hell_tuning.tres`: `player_hurt_radius` 3, `graze_radius` 20,
`graze_meter_gain` 1.5, `dash_graze_mult` 2, `perfect_cancel_radius` 60,
`special_cancel_radius_mult` 1.25, `dash_charges` 2, `dash_recharge_sec` 0.9,
`elite_hp_mult` 1.8, `elite_damage_mult` 1.25, `elite_room_bonus` 0.35,
`reinforcement_warning_sec` 0.6. Per-pattern values in `assets/data/bullet_patterns/`.
Per-floor elite chance and reinforcement groups in `assets/data/enemy_pool_configs/`
(floor 1: 5 %, 2 groups; floor 2: 12 %, 2 groups; floor 3: 20 %, 3 groups).

Rationale: about 67 grazes fill the Special (100 / 1.5), so a dodging player earns about one
Special per dense room on top of hit gain. Two charges at 0.9 s give ~2.2 dashes/s burst
and ~1.1/s sustained, versus 0.5/s before.

## 8. Acceptance Criteria

- AC-BH-01: FAN / RING / SPIRAL angles match the formulas (`bullet_pattern_runner_test`).
- AC-BH-02: A layer fires after `initial_delay`, every `interval`, `bursts` volleys each.
- AC-BH-03: A bullet passing a dashing Faith stays live and grazes for `× dash_graze_mult`.
- AC-BH-04: A close pass adds `graze_meter_gain` once; a far pass adds nothing.
- AC-BH-05: `cancel_in_radius` clears only bullets inside the radius.
- AC-BH-06: Pooled bullets are reused with launch defaults restored.
- AC-BH-07: Laser goes live after `telegraph_sec`; mortar explodes and splashes.
- AC-BH-08: Elites get the HP / damage multipliers and the extra layer; bosses never.
- AC-BH-09: `phase_changed` fires once per distinct HP threshold crossed.
- AC-BH-10: Reinforcements arrive at the trigger count; the wave clears after the last group.
- AC-BH-11: Two dashes back to back; each charge recharges after `dash_recharge_sec`.
