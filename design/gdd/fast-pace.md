# Fast-Pace Layer

> **Status**: Approved (2026-09-24, ADR-0019)
> **Tuning**: `assets/data/pace_tuning.tres` (PaceTuning), `assets/data/sigil_config.tres`,
> `assets/data/enemy_pool_configs/*.tres`
> **Depends on**: bullet-hell.md (ADR-0018)

## 1. Overview

A layer of momentum rules on top of the bullet-hell layer. Dashing through a bullet at
the last moment (Perfect Dodge) slows time and charges the Special. Kills drop HP and
meter orbs that only magnet in when the duo is close. A style meter tracks how
aggressively and cleanly the room was played and turns into an S–D rank with a reward.
Preparation between rooms is one press when nothing changed. Three sigils and a
per-floor difficulty curve push bullet-hell play further as the run goes on.

## 2. Player Fantasy

The duo threads the needle. The best defence is to dive through the pattern and come out
the other side with time slowed and a Perfect ready. Staying in the thick of it is how
she heals and charges up, and a room played with style is visibly graded and paid for.
Between rooms she never waits on a menu she has nothing to do in.

## 3. Detailed Rules

**Perfect Dodge**
1. Counts when an enemy bullet, laser or mortar blast overlaps the active brother's hurtbox while she
   is dashing (dash i-frames only; post-hit grace does not count).
2. At most once per dash, then not again for `perfect_dodge_cooldown_sec`.
3. Effects: `perfect_dodge_time_scale` for `perfect_dodge_slowmo_sec` real seconds, +
   `perfect_dodge_meter_gain` Special meter, + `style_perfect_dodge` style, and the next
   basic cast within `perfect_dodge_cast_window_sec` counts as Perfect whatever its
   timing. The "PERFECT DODGE" callout floats above the duo.
4. The dodged bullet still grazes (×`dash_graze_mult`, bullet-hell.md).

**Kill orbs**
1. Every kill drops `meter_orbs_per_kill` meter orbs (×2 for elites and bosses).
2. An HP orb drops with `hp_orb_chance`; elites and bosses always drop one when
   `elite_always_drops_hp` is on.
3. Orbs pop out, then idle. Inside `orb_magnet_radius` they fly to the duo at
   `orb_magnet_speed` and are collected at `orb_pickup_radius`. Untouched orbs fade after
   `orb_lifetime_sec`.
4. On room clear every orb flies in at `orb_clear_speed_mult` × speed. Orbs left at the
   next preparation phase are removed.
5. HP orbs heal `hp_orb_heal` through HealthAndDamage; meter orbs add `meter_orb_gain`.

**Bullet-cancel meter**: each bullet wiped by a Perfect Cast or a dash cut adds
`cancel_meter_gain`. The Special's own wipe adds nothing.

**Style and rank**
1. Style (0..`style_max`) gains: kill `style_kill`, elite/boss kill `style_elite_kill`,
   graze `style_graze`, Perfect Cast `style_perfect_cast`, Perfect Dodge
   `style_perfect_dodge`. Taking damage costs `style_hit_penalty`.
2. After `style_idle_grace_sec` without a gain, style decays at `style_decay_per_sec`.
3. Style carries over between rooms and resets on a new run.
4. The room rank is taken from the time-weighted average style over the room's combat
   (Formula 2). Rooms with no kills (rest rooms) are not ranked.
5. Rank reward: heal `rank_heal[rank]` now, and the next room starts with
   `rank_meter_bonus[rank]` Special.
6. HUD: live "STYLE <letter>" + bar under the room breadcrumb during combat; "RANK X"
   banner with the reward line at room clear.

**Kill hitstop**: `kill_hitstop_sec` per kill, `elite_kill_hitstop_sec` for elites and
bosses, through SpellVFX's hitstop.

**Quick continue**: when the centre slot is filled and the bag is empty, the confirm
button reads "Continue ▶" and Space (cast key) or Enter starts the room.

**Bullet-hell sigils** (reward pool, SigilConfig):
- *Third Step* (`dash_charge`): + `dash_charge_bonus` dash charges.
- *Severing Dash* (`dash_cut`): while dashing, enemy bullets within `dash_cut_radius`
  are cut (each adds `cancel_meter_gain`).
- *Wide Halo* (`graze_ring`): graze ring × `graze_radius_mult` (stacks).

**Difficulty curve**: each floor's EnemyPoolConfig scales bullet speed
(`bullet_speed_mult`), pattern fire rate (`fire_rate_mult`) and laser / mortar
telegraph length (`telegraph_mult`).

## 4. Formulas

1. **Style decay**: if `idle > style_idle_grace_sec`:
   `style = max(style − style_decay_per_sec × dt, 0)`.
2. **Room average**: `avg = Σ(style × dt) / Σ dt` over the room's combat frames.
   Rank = first `i` with `avg ≥ rank_thresholds[i]` (S, A, B, C), else D.
   Defaults 55 / 40 / 25 / 12: an S needs the meter above half for most of the room.
3. **Orb meter per kill**: `meter_orbs_per_kill × meter_orb_gain × (2 if major)`
   = 3 (normal), 6 (elite). A 12-enemy room at close range is ~36 meter, about a third
   of the Special, on top of hit gains.
4. **Perfect Dodge meter**: `perfect_dodge_meter_gain` = 12, with the 1.0 s cooldown
   capping it at 12/s of dash-dancing, below the Perfect Cast rate.
5. **Difficulty**: bullet speed = `pattern.speed × bullet_speed_mult`; pattern
   cooldown ticks at `dt × fire_rate_mult`; telegraph = `pattern.telegraph_sec ×
   telegraph_mult`. Floors: 1.0/1.0/1.0, 1.1/1.1/0.9, 1.2/1.2/0.8.

## 5. Edge Cases

- **Perfect Dodge during a hitstop**: the slow-mo retries for 0.15 s real time, then is
  dropped (meter, free Perfect and style still apply).
- **Death during a slow-mo or hitstop**: the death slow-mo takes `Engine.time_scale`;
  the earlier warp sees a different scale when it ends and does not restore 1.0.
- **Last kill of the room**: ranking is deferred to the end of the frame, so the last
  kill's orbs and style count, and its orbs are pulled in with the rest.
- **Reward overlay pauses the tree**: orbs still in flight freeze with it and finish
  after the pick; the clear speed boost gets most of them in first.
- **Free Perfect on a miss**: consumed by the next basic cast even if it hits nothing.
- **Multiple sigils**: dash charges add, graze multipliers multiply, dash-cut keeps the
  largest radius.
- **Special fired with a full meter of orbs pending**: orbs keep charging the next
  meter; nothing is lost.

## 6. Dependencies

- bullet-hell.md — hurtbox, graze, bullet cancel, dash charges.
- spell-casting-effects — Special meter, Perfect Cast timing.
- health-and-damage — `enemy_killed`, `damage_taken`, `apply_heal`.
- wave-encounter-system — room clear, spawn-time difficulty.
- sigil-system — reward pool.
- combat-hud — style meter, rank banner, dodge callout, boss bar layout.

## 7. Tuning Knobs

All in `PaceTuning` unless noted. Perfect Dodge: time scale (0.2–0.5), slow-mo length,
meter gain, cooldown, free-Perfect window. Orbs: HP chance, heal, meter per orb, orbs
per kill, magnet radius / speed, pickup radius, lifetime, clear pull and speed.
Cancel meter gain. Style: max, per-event gains, hit penalty, idle grace, decay, rank
thresholds, rank heal / meter tables. Kill hitstop lengths. Quick continue on/off.
SigilConfig: `dash_charge_bonus`, `dash_cut_radius`, `graze_radius_mult`.
EnemyPoolConfig: `bullet_speed_mult`, `fire_rate_mult`, `telegraph_mult`.

## 8. Acceptance Criteria

- A dash through a bullet that would hit counts one Perfect Dodge per dash, never from
  post-hit grace, and grants meter, style and a free Perfect (tests/unit/fast-pace/
  perfect_dodge_test.gd).
- Style gains cap, decay only after the grace, drop on hit, and rank from the
  time-weighted average (style_meter_test.gd).
- A time warp never overrides another and only restores its own scale
  (time_warp_test.gd).
- Orbs idle outside the magnet radius, fly in inside it, collect once, and are pulled in
  on clear (pickup_orb_test.gd); drop counts follow the table.
- A room with kills is ranked once, pays the heal and banks the meter bonus for the
  next room; rooms without kills are not ranked (pace_director_test.gd).
- Floor configs get harder floor by floor; fire rate and telegraph scale as configured
  (difficulty_curve_test.gd).
- Quick continue is available only with a centre Prana, an empty bag, in ARRANGEMENT
  (quick_continue_test.gd).
- Visual: boss bar and name card never overlap the HP bar; see
  production/qa/evidence/fast-pace-evidence.md.
