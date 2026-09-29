# Perfect Cast & Special Attack

> **Status**: Implemented (2026-09-24) — first pass, needs playtest tuning
> **System**: extends Spell Casting & Effects (#9); reads Combination Resolution output
> **ADR**: ADR-0017 (Perfect Cast timing + Special attack in SC&E)
> **Tuning**: `assets/data/attack_tuning.tres` (`AttackTuning`)

## 1. Overview

Combat gets two buttons. **Basic** (SPACE / A) is the existing chain, now judged on
rhythm: after each attack's cast lock ends a short **Perfect window** opens. A press
inside it is **Perfect** (more damage, more Special meter, a stronger Cascade); a press
before it is **Rushed** (weaker, no meter, no Cascade); a later press is **Normal**.
**Special** (F / right mouse / Y) spends a full meter on one large burst around the active brother.
Its **shape and signature** come from the core Prana, every **non-primary Prana** in the
grid **infuses** its element facet, and armed **reactions** ride on it because it uses
the same Burn / Blind / Stun / Freeze primitives. The Special is where the whole grid
shows up at once, not just the centre slot.

## 2. Player Fantasy

"I read the arena, built my grid, and now I play it like an instrument." Mashing still
works but feels thin; finding the beat makes numbers jump, the meter fill, and the
Cascade bloom. The Special is the payoff moment: a storm, an eclipse, a glacier, shaped
by everything the player put on the grid. Two grids with the same core feel different
because their Specials carry different infusions.

## 3. Detailed Rules

### Rule 1 — Two actions
- `cast` (basic): SPACE, gamepad A. Unchanged chain rules (TR-SC-002).
- `special`: F, right mouse, gamepad Y. Registered by SC&E `_ready()` (keys/mouse) and by
  the scene input setup (pad). Y and A are prep-only in the grid, so there is no clash.

### Rule 2 — Cast timing judgement (basic presses only)
Let `elapsed` = seconds since the current cast lock ended (the combo window opened).
Only presses made while the chain is **CHAINING** are judged:

| Condition | Judgement | Damage | Meter | Cascade on final hit |
|---|---|---|---|---|
| Chain start from READY | Normal | ×1.0 | +`special_gain_hit` | ×1.0 |
| CHAINING, `elapsed < perfect_window_start` | **Rushed** | ×`rushed_damage_mult` | none | **does not fire** |
| CHAINING, `start ≤ elapsed ≤ end` | **Perfect** | ×`perfect_damage_mult` | +`special_gain_perfect` | ×`perfect_cascade_mult` |
| CHAINING, `elapsed > end` | Normal | ×1.0 | +`special_gain_hit` | ×1.0 |

A press buffered during cast lock fires the instant the lock ends (`elapsed = 0`), so a
buffered/mashed press is always Rushed. Meter is only gained on a *landed* attack
(any enemy hit, or a secondary attack slot such as the Verdant shield pulse).
Consecutive Perfects build a streak shown as "PERFECT ×N"; any non-Perfect press or
chain expiry resets it.

### Rule 3 — Special meter
- Range 0..`special_meter_max` (100). Capped. Resets to 0 every preparation phase
  (wave-scoped, same as the rest of SC&E state — ADR-0009).
- The Special fires only when the meter is full; firing spends all of it.
- The Special **overrides cast lock** (it is never swallowed mid-chain), ends the basic
  chain (`_combo_index = 0`), and applies its own lock (`special_lock_duration`).

### Rule 4 — Special = Shape (core) + Infusions (non-primary) + Reactions (adjacency)
The three layers map one-to-one onto the grid's three resolution layers, so the Special
is readable from the grid preview alone:

| Grid layer (CR) | Special layer | What it decides |
|---|---|---|
| Core type + primary tier | **Shape & signature** | Where it hits, the unique mechanic, raw damage |
| `non_primary_modifiers` (type + NP tier) | **Infusions** | Extra facet per supporting element, stronger at NP T2 |
| `active_reactions` (adjacent pairs) | **Reactions ride along** | Triggered by the facets, same rules as basic hits |

#### 4a. Core shapes and signatures (centred on the duo)

| Core (verb) | Name | Reach | Status | Signature |
|---|---|---|---|---|
| Ashfire (IGNITE) | **Eruption** | `special_radius` | Burn `special_burn_duration` (via `_apply_burn`, so Witchfire/Wildfire fire) | Enemies already Burning take ×`eruption_burning_mult` — the Special *consumes* fire |
| Voidblue (SUPPRESS) | **Eclipse** | `special_wide_radius` | Blind `special_blind_duration` | Pulls every enemy hit up to `eclipse_pull_distance` toward the active brother (never past her) — groups them for the next cone |
| Stormgold (CHAIN) | **Thunder Chain** | nearest `special_chain_targets` within wide radius | Stun `special_stun_duration` (via `_apply_stun`, so Short Circuit fires) | Picks targets anywhere in reach, no falloff; Superconduct arcs off a Frozen first target |
| Deepfrost (BIND) | **Glacier** | `special_radius` | Freeze `special_freeze_duration` | Freeze lands *after* the damage — it is setup, the next basics Shatter |
| Verdant (NOURISH) | **Sanctuary** | `special_radius` | Regen on the duo `sanctuary_regen_duration` | Heals the duo `special_heal_ratio × special damage` once (if anything was hit) |

#### 4b. Infusions (each non-primary entry; NP T2 multiplies by `infusion_tier2_mult`)

| Non-primary | Facet on the Special |
|---|---|
| Ashfire | Burn `infusion_burn_duration` on every enemy hit |
| Voidblue | Blind `infusion_blind_duration` on every enemy hit |
| Stormgold | Arcs to `infusion_arc_targets` extra nearest enemies *outside* the shape (within wide radius) for 50% Special damage, Stunning them |
| Deepfrost | Freeze `infusion_freeze_duration` on every enemy hit |
| Verdant | Heals the duo a flat `infusion_heal` |

An entry whose type equals the core is ignored (defensive — CR never emits one).

#### 4c. Reactions on the Special
The Special runs through `_special_hit`, which keeps the reaction hooks of `_apply_hit`:
Shatter, **Thermal Shock** (first hit per target), **Siphon** (hit on a Blinded enemy),
**Detonate** (first kill). Status facets go through `_apply_burn` / `_apply_stun`, so
**Witchfire**, **Wildfire** and **Short Circuit** fire from them. Firing the Special
resets the once-per-chain reaction flags first, so the Special counts as its own cast.
Surge (per basic hit) and Permafrost (passive) are unaffected. Whiteout still has no
effect anywhere (Blind has no miss chance yet — pre-existing gap).

## 4. Formulas

**Formula 1 — Special damage (per enemy, before Shatter / reactions / sigils)**

`special_damage = BASE_SPELL_DAMAGE × clamp(bdm, 0, 1.40) × special_damage_mult × (1 + special_tier_bonus × (primary_tier − 1))`

| Core | bdm | T1 | T2 | T3 |
|---|---|---|---|---|
| Ashfire | 1.25 | 75 | 93.8 | 112.5 |
| Stormgold | 1.15 | 69 | 86.3 | 103.5 |
| Voidblue | 0.90 | 54 | 67.5 | 81 |
| Deepfrost | 0.80 | 48 | 60 | 72 |
| Verdant | 0.70 | 42 | 52.5 | 63 |

Final per-enemy = `special_damage × (eruption_burning_mult if Ashfire and Burning) × shatter/thermal × run_damage_mult`.
Reference HP: Cluster 30, Rifter 32, Drifter 50, Charger 90, Vault Sentinel 250, Warden 500.
A T1 Special one-shots every trash enemy except Charger; it is a room-clear, not a boss-killer.

**Formula 2 — Why Rushed must be weaker (throughput check, single target)**

Press rate is bounded by cast lock (`L` = 0.12 s, Ashfire 0.20 s). Perfect cadence is
about `L + 0.30` s (middle of the window).

| Style | Ashfire T1 (basic 25) | Voidblue T1 (basic 18) |
|---|---|---|
| Mash, Rushed ×0.5 (1/L presses/s) | 5/s × 12.5 = **62.5 DPS**, 0 meter | 8.3/s × 9 = **75 DPS**, 0 meter |
| Perfect rhythm (1/(L+0.30)) | 2/s × 32.5 = 65 + Special every 2.5 s (75 ×1.5 burning) = **~110 DPS** | 2.4/s × 23.4 = 56 + Special every 2.1 s (54) = **~82 DPS** |
| Relaxed Normal (0.8 s) | 1.25/s × 25 = 31 + Special every 10 s = **~40 DPS** | 1.25/s × 18 = 22.5 + Special every 10 s = **~28 DPS** |

Without the Rushed penalty, mashing at 8 presses/s would out-damage *and* out-charge the
rhythm (8 × 8 = 64 meter/s vs 2.4 × 20 = 48/s) — the Perfect system would be decorative.
With Cascade builds the gap widens: T1 Cascade (×1.2) fires every press, so Rushed must
not fire it, or mashing gets ~8 Cascades/s.

**Formula 3 — Meter fill**: hits to full = `special_meter_max / gain` → 13 Normal hits or
5 Perfect hits at defaults.

## 5. Edge Cases

- **Special with no enemy in reach**: meter is spent, burst still plays; Verdant still
  grants Regen but no instant heal (needs a hit). Intentional — firing blind is a mistake.
- **Stormgold chain with fewer enemies than `special_chain_targets`**: hits all in reach.
- **Stormgold infusion when the shape already hit everyone**: arc finds nothing, no-op.
- **Special pressed during cast lock**: fires immediately (overrides lock).
- **Special pressed in IDLE / preparation**: ignored; meter unchanged.
- **Kill during the Special**: Detonate can fire (once); later facets skip dead enemies.
- **Knockback moves enemies out of melee reach between presses** (seen in the training
  room screenshot): a Perfect press that hits nothing gains no meter and no streak. The
  player must keep pressure by stepping in — keeps movement relevant.
- **Buffered press** is always Rushed by construction (elapsed = 0).
- **Secondary attack slots** (Verdant shield pulse, Deepfrost glacial field) count as
  landed for meter and streak.

## 6. Dependencies

- **Spell Casting & Effects** (#9) — owner; new signals `perfect_cast`,
  `special_meter_changed`, `special_fired`; public `get_cast_timing()`,
  `is_in_perfect_window()`, `get_special_meter()`, `is_special_ready()`,
  `get_special_damage()`.
- **Combination Resolution** — reads `primary_type/tier`, `base_damage_modifier`,
  `non_primary_modifiers`, `active_reactions`, `active_cascade` (no CR change).
- **Status Effects Manager** — Burn/Blind/Stun/Freeze/Regen via `apply_status` (ADR-0011).
- **Health & Damage** — `apply_damage`, `apply_heal`.
- **Combat HUD** — Special meter bar + ready prompt. **SpellVFX** — Perfect callout,
  sweet-spot marker on the combo ring, Special burst ring + heavy shake.
- **UICopy** — `perfect_label`, `special_label`, `special_ready_label`.

## 7. Tuning Knobs

All in `AttackTuning` (`assets/data/attack_tuning.tres`). Key ones:

| Knob | Default | Safe range | Too low | Too high |
|---|---|---|---|---|
| `perfect_window_start` | 0.18 s | 0.10–0.30 | Mashing lands Perfects | Rhythm feels sluggish |
| `perfect_window_end` | 0.42 s | 0.30–0.60 | Too strict | No skill expression |
| `perfect_damage_mult` | 1.3 | 1.1–1.6 | Perfect not felt | Rhythm mandatory |
| `perfect_cascade_mult` | 1.5 | 1.2–2.0 | — | T1 Cascade builds dominate |
| `rushed_damage_mult` | 0.5 | 0.4–0.8 | Mashing feels broken | Mashing beats rhythm (Formula 2) |
| `special_gain_hit` / `_perfect` | 8 / 20 | 5–12 / 15–30 | Special rare | Special spam |
| `special_damage_mult` | 3.0 | 2.0–4.0 | Special underwhelms | Trivialises rooms |
| `special_tier_bonus` | 0.25 | 0.1–0.4 | Mono builds lose identity | Mono dominates |
| `eruption_burning_mult` | 1.5 | 1.0–1.6 | — | Ashfire best core by default (see Risks) |
| `infusion_tier2_mult` | 2.0 | 1.5–2.5 | NP investment pointless | Support stacking beats core |

## 8. Acceptance Criteria

Covered by `tests/unit/spell-casting-effects/sce_perfect_special_test.gd` and
`tests/unit/combat-hud/combat_hud_special_meter_test.gd`:

- AC-PS-01 Perfect window true only while CHAINING and within [start, end].
- AC-PS-02 Perfect hit = base × `perfect_damage_mult`; Rushed = × `rushed_damage_mult`, no meter; late = Normal.
- AC-PS-03 Streak counts consecutive Perfects and resets on a non-Perfect press.
- AC-PS-04 Perfect final hit multiplies the Cascade; a Rushed final hit fires no Cascade.
- AC-PS-05 Meter: +hit / +perfect on landed attacks only, capped, reset in preparation.
- AC-PS-06 Special blocked below full meter; spends meter, ends chain, sets its lock.
- AC-PS-07 Each core's shape, status, and signature (5 tests).
- AC-PS-08 Infusions: Deepfrost scales with NP tier; Stormgold arcs beyond the shape; Verdant heals; core-typed entries ignored.
- AC-PS-09 Witchfire and Siphon trigger from the Special.
- AC-PS-10 HUD bar fills, shows the ready prompt when full, visible only in combat.

---

## Appendix A — Combination analysis

### A1. What each grid layer did before this change

| Layer | Affected combat? | Note |
|---|---|---|
| Core type + tier | Yes | Chain length, damage, status |
| Reactions (adjacent pairs) | Yes (PR #66) | Riders on basic hits |
| Cascade (core + ≥2 cardinal neighbours) | Yes (PR #66) | Burst on the chain's final hit — every press at T1 |
| **Non-primary tiers** | **No** | Computed by CR, never read by SC&E — fragment *counts* of support types were meaningless |
| Adjacency effects | No | Random per fragment, not applied |

So before this change, a support type mattered only by *where* it sat (adjacency), never
by *how much* of it you had. The Special gives non-primary tiers their first combat
effect, which makes a real trade-off out of every fragment placed off-centre:
more core = longer chain + stronger Special shape; more support = stronger infusion.

### A2. Core × infusion matrix (20 pairings)

"Rides" = reaction that arms when the two types are also cardinally adjacent.

| Core ↓ / Infusion → | +Ashfire | +Voidblue | +Stormgold | +Deepfrost | +Verdant |
|---|---|---|---|---|---|
| **Ashfire Eruption** | — | Blind on all. Rides Witchfire (redundant Blind — weak pairing) | Arcs beyond radius + Stun. Rides Detonate → first kill bursts. **Best clear** | Freeze after burst → next basics Shatter. Rides Thermal Shock (×1.25 on Special) | +8/16 HP. Rides Wildfire (Burn spreads). Sustain aggro |
| **Voidblue Eclipse** | Burn on the pulled cluster, so the group takes damage over time while it is packed. Rides Witchfire (redundant Blind) | — | Arcs + Stun on stragglers outside the pull. Rides Short Circuit. **Control** | Freeze the pulled cluster (enemies grouped *and* rooted). Rides Whiteout (**no effect yet**) | Heal. Rides Siphon: Void basics already Blind targets, so every Special hit heals 20% → **strongest sustain (risk)** |
| **Stormgold Thunder Chain** | Burn along the chain. Rides Detonate | Blind along the chain. Rides Short Circuit (redundant — all already stunned) | — | Freeze along the chain. Rides Superconduct only if the first target was already Frozen | Heal. Rides Surge (basics only) |
| **Deepfrost Glacier** | Burn + Freeze together (no conflict rule). Rides Thermal Shock | Blind + Freeze. Rides Whiteout (**no effect yet**) | Arcs outside the field. Rides Superconduct (Deepfrost basics Freeze the primary, so it fires reliably). **Best control** | — | Heal. Rides Permafrost (Freeze → Regen ×1.5). **Tank** |
| **Verdant Sanctuary** | Burn around the active brother. Rides Wildfire | Blind around the active brother. Rides Siphon | Arcs + Stun, turns the defensive burst offensive | Freeze around the active brother. Rides Permafrost on the Sanctuary Regen — **self-synergy** | — |

### A3. Build archetypes the system now supports

| Archetype | Grid | Special | Trade-off |
|---|---|---|---|
| **Mono** | 6+ core fragments | T3 shape ×1.5, no infusions | Highest raw damage, no utility, no reactions/Cascade |
| **Cross** | Core + 2–4 distinct neighbours (1 each) | T1 shape + 2–4 T1 infusions; Cascade every chain | Most facets, weakest numbers; relies on Perfect for Cascade power |
| **Pair** | Core + 3 of one support type adjacent | T1–T2 shape + one T2 infusion + its reaction | Deep synergy on one axis (e.g. Deepfrost + 3 Stormgold) |

No archetype dominates on paper: Mono wins single-target, Cross wins crowds and needs
rhythm, Pair wins specific enemy mixes. This is the target of Pillar 4 (Depth Over Breadth).

### A4. Risks found (for playtest)

1. **Ashfire self-synergy.** Ashfire basics always Burn, so Eruption almost always gets
   ×1.5 — effectively 112 damage at T1. Ashfire may become the default core. Knob:
   `eruption_burning_mult`.
2. **Voidblue + Verdant Siphon.** Void basics Blind; a wide Eclipse on 5 Blinded
   enemies heals 5 × 54 × 0.20 ≈ 54 HP of the duo's 100. Consider capping Siphon per cast.
3. **T1 Cascade frequency** (pre-existing): Cascade fires on every T1 press. The Rushed
   rule stops mashing from abusing it, and Perfect ×1.5 makes the rhythm the way to earn it.
4. **Redundant pairings** (Witchfire + Void infusion, Short Circuit + Thunder Chain):
   low value, but readable; they teach the player to diversify.
5. **Whiteout** still has no effect (needs a Blind miss-chance mechanic).
6. **Voidblue single-target margin** is thin (Formula 2: 82 vs 75 DPS). If mashing still
   feels as good, lower `rushed_damage_mult` to 0.4.
