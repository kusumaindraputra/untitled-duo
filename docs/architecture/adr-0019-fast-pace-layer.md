# ADR-0019: The Fast-Pace Layer (Perfect Dodge, Kill Orbs, Style Rank)

## Status

Accepted

## Date

2026-09-24

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Combat rewards momentum. A dash through a bullet that would have hit is a **Perfect
Dodge**: a short slow-mo, Special meter and a free Perfect on the next cast. Kills drop
**HP and meter orbs** that magnet to the duo, so standing close pays. Bullets wiped by a
Perfect Cast or a dash cut feed the meter. A **style meter** rises with kills, grazes
and Perfects and decays when passive or hit; each room ends with an **S–D rank** that
heals and gives the next room a Special head start. Kills get a hitstop. Preparation
gets a one-press **Continue** when nothing changed. Three bullet-hell sigils (third
dash charge, dash cuts bullets, wider graze ring) and a per-floor **difficulty curve**
(bullet speed, fire rate, telegraph length) round it out. All knobs live in
`PaceTuning` (`assets/data/pace_tuning.tres`), `SigilConfig` and `EnemyPoolConfig`.
Design: `design/gdd/fast-pace.md`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay / Core (time scale) / UI |
| **Knowledge Risk** | LOW — `Engine.time_scale`, `SceneTree.create_timer(sec, process_always, process_in_physics, ignore_time_scale)`, `Tween.set_ignore_time_scale`, `Control.set_anchors_and_offsets_preset` are unchanged since 4.0 |

## ADR Dependencies

- ADR-0018 (bullet-hell layer) — Perfect Dodge hooks the same hurtbox checks in
  `Projectile`, `EnemyLaser` and `MortarShell`; the difficulty curve scales
  `BulletPatternRunner`.
- ADR-0003 (signal-driven) — `PaceDirector` only consumes autoload signals and emits
  its own; the HUD never reads its state.
- ADR-0004 (float accumulators) — style decay, orb flight and the free-Perfect window.

## Context

The bullet-hell layer made enemy fire dense, but nothing pushed the player to play
*toward* it: the safest play was to kite at range, and between rooms the player sat
through a preparation panel even when there was nothing to place. Several effects also
wrote `Engine.time_scale` independently (SpellVFX hit hitstop, the heavy-hit stop and
death slow-mo in `debug_game_loop`, SpellVFX death), and any new slow-mo would fight
them. Separately, the boss bar and name card were anchored inside a 0×0 `CombatHUD`
root, so they collapsed onto the top-left corner over the duo's HP bar.

## Decision

1. **`PaceDirector` node** (`src/systems/pace_director.gd`), created and wired by
   `debug_game_loop._ready()` like `SigilManager`. It listens to `enemy_killed`,
   `damage_taken`, `grazed`, `perfect_cast`, GSM phase signals and the player's new
   `perfect_dodged` signal, and emits `style_changed`, `room_ranked` and
   `perfect_dodge_triggered` for the HUD. Room ranking runs deferred so the last kill's
   `enemy_killed` handlers (orb drops, style) land first.
2. **Pure rules** live in RefCounted / static code with headless tests:
   `StyleMeter` (gain, idle-grace decay, hit penalty, time-weighted room average, rank
   thresholds), `TimeWarp` (the time-scale guard), `PickupOrb.step()` and
   `PaceDirector.orb_drops()`.
3. **One time-scale rule (`TimeWarp`)**: a warp starts only while time runs at normal
   speed, and restores 1.0 only if the scale is still the value it set. SpellVFX's
   hitstop now follows it (it extends itself but never overrides another warp, and
   never restores over one). Kill hitstop goes through `SpellVFX.request_hitstop()` so
   there is one hitstop owner. A Perfect Dodge that lands during a hitstop retries for
   0.15 s real time.
4. **Perfect Dodge detection stays in the hazards**: where a hazard already checks
   The active brother's hurtbox and sees her dashing, it calls
   `PlayerController.register_perfect_dodge()`. The player owns the rules (dash only —
   not post-hit grace — once per dash, cooldown).
5. **Meter entry points** on `SpellCastingEffects`: public `add_special_meter()` and
   `grant_perfect_cast(window)`. The free Perfect is consumed by the next basic cast.
   The Special's own bullet wipe grants no meter, so the Special cannot refill itself.
6. **Difficulty curve per `EnemyPoolConfig`** (`bullet_speed_mult`, `fire_rate_mult`,
   `telegraph_mult`), applied by `WaveManager` at spawn through
   `EnemyInstance.apply_difficulty()`. Floor 3's boss gets its own config
   (`enemy_pool_boss_f3.tres`) so it can be tuned harder than floor 1's.
7. **HUD root fills the viewport** (`PRESET_FULL_RECT`, `MOUSE_FILTER_IGNORE`), and the
   boss bar / name card are laid out in pixels, kept clear of the left column, and
   re-laid out on viewport resize.

## Alternatives Considered

- **Perfect Dodge as a timing window at dash start** (bullet within N px when the dash
  begins): closer to the fiction of "just before impact", but needs a spatial query per
  dash and false-positives on bullets flying away. Rejected for the hurtbox-overlap
  rule, which reuses existing checks and can only fire on a real would-be hit.
- **Central time-scale stack autoload**: most robust, but touches every existing
  writer. The two-rule guard covers the real conflicts with a small diff.
- **Style rank from the meter at room end**: rewards one lucky final burst and is
  always high (the last kill just fired). The time-weighted average rewards sustained
  aggression.
- **Auto-continue preparation on a timer**: faster still, but surprises players who
  wanted to rearrange. One press is explicit and near-instant.

## Consequences

- Positive: aggression, grazing and dash timing are all rewarded; room-to-room flow is
  one press when nothing changed; time-scale effects no longer cut each other short.
- Negative: more HUD elements (style meter, rank banner, dodge callout). The free
  Perfect makes Perfect Casts easier after a dodge; tuned via
  `perfect_dodge_cast_window_sec` (0 disables).
- The boss HUD fix also makes the anchored recognition callout and DESPERATE vignette
  render at their intended full-width positions.

## Validation

- `tests/unit/fast-pace/` (style meter, time warp, orbs, Perfect Dodge, PaceDirector,
  difficulty curve, quick continue) and `tests/unit/sigil-system/sigil_bullet_hell_test.gd`.
- Visual evidence: `production/qa/evidence/fast-pace-evidence.md`.
