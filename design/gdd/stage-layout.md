# Stage Layout: Cover, Hazards, Floor Identity

> **Status**: Approved *(2026-09-25, ADR-0020)*
> **Implements Pillars**: Pillar 1 (Every Run Tells a Different Story), Pillar 3 (Chaos Has Consequences)

## 1. Overview

Every room has three layers that shape a fight: its **shape** (Diamond, Split,
Corridor, Arena, Narrow, and now Ring and Cross), its **cover** (half-cover debris
plus full-cover pillars that stop enemy fire), and its **hazards** (turrets, sweep
lasers, floor vents, a closing ring). Each floor picks rooms from its own pool and has
its own look, so floor 1 teaches, floor 2 adds lanes and turrets, and floor 3 puts it
all together.

## 2. Player Fantasy

The room is a weapon, and you learn to read it. A pillar saves you from a ring of
bullets, but you can watch it crack and know it won't last. A laser sweeping out of the
core tells you when to move. On floor 3 the edge of the room closes in, and every
dash has to count.

## 3. Detailed Rules

### Cover

| Type | Blocks walking | Blocks enemy bullets | Blocks lasers | Blocks Prana | Wears down |
|------|----------------|----------------------|---------------|--------------|------------|
| Debris (half cover) | Yes (not while dashing) | No | No | No | No |
| Pillar (full cover) | Yes (also while dashing) | Yes | Yes (beam cut short) | No | Yes |

- A bullet that hits a pillar despawns and costs the pillar 1 hit. An enemy laser that
  a pillar cuts short costs it `CoverPillar.LASER_HITS` (3). Mortars arc over pillars.
  Sweep-laser hazards are cut short but do not wear pillars down.
- A pillar shows 3 crack stages and crumbles at 0 hits (chip burst, collision off).
- Pillars take interior floor tiles at least 120 px from spawn markers, Fayde's start and
  the door slots, keep `min_center_dist` from the room centre, stay
  `pillar_min_between_dist` apart and avoid debris and hazards.

### Hazards

All hazards are idle in preparation. They switch on at `combat_started` and off at
wave end, room clear and death. Damage uses the CONTACT source, so dash i-frames and
post-hit grace apply.

| Kind | Behaviour |
|------|-----------|
| **Turret** | Fires its `BulletPattern` at Fayde (same runner as enemies: windup glow, fan / ring). Its base is half cover. It cannot be destroyed. |
| **Sweep laser** | 1–4 beam arms rotate around a pylon. There is a harmless telegraph for `warmup_sec`, then the beams are live. Touching one deals damage. Dashing through one counts as a Perfect Dodge. Passing close grazes. Beams stop at pillars and, unless `stop_at_walls` is off, at walls. |
| **Floor vent** | Cycles dormant → telegraph (growing glow) → burning. It hurts only while burning and only inside its iso circle. `phase_offset` staggers vents. |
| **Closing ring** | After `ring_delay_sec`, the safe diamond shrinks from `ring_start_scale` to `ring_min_scale` over `ring_close_sec`. Standing outside it hurts. |

### Shapes (new)

- **Ring** (`layout_style = 5`): the room diamond with a walled core (diamond norm < 0.3).
  The core blocks walking and bullets. A sweep pylon can sit in it with
  `stop_at_walls = false` and `arm_inner_radius` set.
- **Cross** (`layout_style = 6`): only tiles with |x| ≤ 128 or |y| ≤ 80 px are kept,
  forming four arms and a hub. Enemies funnel in along the arms.

### Floors

| Floor | Name | Look | Combat pool (weight) | Elite | Boss room |
|-------|------|------|----------------------|-------|-----------|
| 1 | Deep Scrap Yard | Sand floor, grey pillars | Diamond 3, Split 2, Corridor 2, Arena 2 | Split, Corridor, Gauntlet | The Gate (pillars) |
| 2 | Functional Corridors | Blue-grey tint, blue pillars | Crossfire 3 (Cross + sweep), Watchtower 2 (Ring + 2 turrets), Vent Line 2 (Corridor + 3 vents), Divide 2 (Split + turret), Diamond 1 | Kill Box (Cross + 2 turrets), Crossfire, Gauntlet | The Warden's Ring (Ring + pillars) |
| 3 | Cipher Core | Mauve tint, violet pillars | Core 3 (Ring + 3-arm core sweep + vent), Crucible 2 (closing ring + ring turret), Junction 2 (Cross + reverse sweep + turret), Furnace 2 (3 vents + turret) | Sanctum (Ring + 4-arm sweep + ring), Junction | The Last Cipher (slow closing ring) |

A floor-intro banner ("FLOOR 2 / Functional Corridors") shows when each floor starts,
and the HUD floor label shows the floor name.

## 4. Formulas

```
pillar crack stage = clamp(floor((1 - hits_left / max_hits) × 4), 0, 3)

vent cycle         = off_sec + telegraph_sec + on_sec
vent local time    = fposmod(t + phase_offset, cycle)
vent phase         = DORMANT if local < off_sec
                     TELEGRAPH if local < off_sec + telegraph_sec
                     BURNING otherwise

sweep arm angle    = deg_to_rad(rotation_deg_per_sec) × t + TAU × arm / arm_count

ring safe scale    = ring_start_scale                                  if t ≤ delay
                     lerp(start, min, clamp((t − delay) / close, 0, 1)) otherwise
outside ring       = |x| / half_x + |y| / half_y > safe scale

iso circle hit     = length(dx, 2·dy) ≤ radius
```

## 5. Edge Cases

- **No room for pillars** (narrow rooms, crowded spawns): fewer pillars, or none. That is valid.
- **A random hazard finds no free tile**: it is skipped, and the room still builds.
- **The pillar Fayde hides behind breaks**: its collision turns off on the next
  physics step, so bullets already in flight carry on.
- **Several hazards in a multi-wave room**: they switch off between waves and restart
  their timers each wave, so a vent never burns during preparation.
- **The sweep pylon sits inside the Ring core**: the core's rim would block the beam at
  once, so core templates set `stop_at_walls = false`. The beam then runs over the
  void past the outer edge, where Fayde cannot stand.
- **The first room of a run**: `main.tscn` ships its own room without a template, so
  floor 1's first room is a plain diamond with no pillars. Later rooms use the themes.

## 6. Dependencies

| System | Relationship |
|--------|--------------|
| Level Generation (`design/gdd/level-generation.md`) | Debris placement is unchanged; pillars and hazards are placed after it and avoid it. |
| Bullet Hell (`design/gdd/bullet-hell.md`) | Bullets despawn on pillars and walls. Turrets reuse `BulletPattern`. |
| Fast-Pace (`design/gdd/fast-pace.md`) | Sweep lasers can trigger Perfect Dodge. |
| Health & Damage | All hazard damage goes through `HealthAndDamage.apply_damage` (CONTACT). |
| Game State & Scene Flow | Hazards follow `combat_started` / `preparation_started` / `wave_ended` / `room_cleared` / `death_started`. |
| Combat HUD | Floor label and floor-intro banner (text in `UICopy.floor_*`). |

## 7. Tuning Knobs

| Where | Knob | Default |
|-------|------|---------|
| `ObstacleConfig` (`assets/data/obstacle_configs/*.tres`) | `pillar_count_min/max` | combat 2–3, elite 2–3, boss 3–4, rest 0 |
| | `pillar_hits` | combat 24, elite 24, boss 32 |
| | `pillar_radius`, `pillar_min_between_dist` | 20 px, 150 px |
| `HazardSpec` (inline in room templates) | `damage` | 7–8 |
| | turret `pattern` | `turret_burst` (3-way fan ×3) or `turret_ring` (12-ring) |
| | sweep `arm_count`, `rotation_deg_per_sec`, `arm_length`, `warmup_sec` | per room |
| | vent `off_sec / telegraph_sec / on_sec`, `zone_radius` | 2.2 / 0.9 / 1.3 s, 56 px |
| | ring `ring_delay_sec / ring_close_sec / ring_min_scale` | per room |
| `FloorTheme` (`assets/data/floor_themes/*.tres`) | pools and weights, `floor_tint`, `pillar_color`, `debris_tint` | per floor |
| `UICopy` | `floor_names`, `floor_label_format`, `floor_intro_format` | |

## 8. Acceptance Criteria

| ID | Criterion | Test |
|----|-----------|------|
| AC-SL-01 | A bullet that reaches a pillar stops and costs it 1 hit | `cover_pillar_test::test_flying_bullet_is_stopped_by_pillar` |
| AC-SL-02 | A pillar breaks exactly on its last hit and emits `destroyed` once | `cover_pillar_test` |
| AC-SL-03 | Fayde cannot walk or dash through a pillar; dash still passes debris and enemies | `cover_pillar_test::test_fayde_cannot_walk_or_dash_through_pillars` |
| AC-SL-04 | A laser beam cast at a pillar is cut short and reports the pillar | `cover_pillar_test::test_laser_blocked_by_pillar_in_tree` |
| AC-SL-05 | Vent phases follow the cycle and phase offset | `hazard_logic_test` |
| AC-SL-06 | Sweep arms are spread evenly and harmless during warmup | `hazard_logic_test` |
| AC-SL-07 | The closing ring holds, then closes to its minimum | `hazard_logic_test` |
| AC-SL-08 | Every floor theme has combat, elite, rest and boss rooms; floors 2–3 have at least 3 combat rooms floor 1 never uses | `stage_layout_test` |
| AC-SL-09 | Every themed room builds with its pillars on floor tiles ≥ 120 px from spawn markers and all its hazards built | `stage_layout_test` |
| AC-SL-10 | The Ring has an empty core; the Cross keeps its hub and cuts its corners | `stage_layout_test` |
| AC-SL-11 | The generator only assigns templates from the applied floor theme | `stage_layout_test::test_generator_uses_theme_pools` |
