# Duo Swap — Ayden and Faith

> **Status**: Proposal (2026-09-28) — design only, no code yet
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Extends**: player-controller.md, spell-casting-effects.md, special-attack.md,
> bullet-hell.md, fast-pace.md, ADR-0057 (two hands on the grid)
> **Reference**: Cloak & Dagger (Marvel Rivals) — one player, two heroes, swap on a button,
> each with a different kit, and a tag-in moment that rewards timing
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding),
> Pillar 3 (Chaos Has Consequences)

## 1. Overview

In combat the player controls one of two characters at a time, **Ayden** (power) or
**Faith** (control), and swaps between them with one button. Only the active one is in
the arena; the other rests inside Fayde's frame. They share one HP bar, one Special meter
and one Prana grid, but they read that grid differently and fight differently: Ayden is
close range, heavy hits and knock-back; Faith is long range, status and bullet control.
Swapping is fast and cheap, has a short tag-in effect, and a well-timed swap (a **Perfect
Swap**) is the duo version of the Perfect Dodge.

The grid already says this (ADR-0057): the left column is Ayden's hand, the right column
is Faith's. This proposal turns those two hands into two playable characters.

## 2. Player Fantasy

"Two brothers, one fight, and I decide who steps in." Ayden bursts in when a pack is
bunched up; Faith takes over when the screen fills with bullets and something needs
freezing. The best moments are the hand-offs: Faith roots the elite, swap, Ayden's first
hit lands on the frozen target for a shatter. Swapping never feels like a menu; it feels
like one brother passing the fight to the other mid-motion.

The story payoff: early runs feel like controlling two ghosts in one body. By the true
ending ("You're both of them. And you're you.") the player has literally been both of them
all along.

## 3. Detailed Rules

### Rule 1 — One active character
- Combat starts with the character chosen at the end of Preparation (default: whoever was
  active last room; first room of a run: Ayden).
- Only the active character moves, casts and has a hurtbox. The inactive one is not in the
  arena and cannot be hit.
- Movement, dash charges, graze, orbs and style work the same for both (bullet-hell.md,
  fast-pace.md). Tuning differences are in Rule 4.

### Rule 2 — Swap
- `swap` action: **Q**, gamepad **LB**. Allowed in COMBAT_PHASE while ENABLED or DASHING.
- Swap is instant and keeps position, velocity and facing. The current basic chain ends.
- Cooldown `swap_cooldown_sec` (default 1.2 s). The HUD shows it on the portrait.
- **Tag-in**: the character swapping in grants `swap_iframe_sec` (0.2 s) of i-frames and
  fires a small tag-in effect (Rule 5).
- Swapping during the Special's lock is allowed but does not cancel the Special.

### Rule 3 — Perfect Swap
- Counts when an enemy bullet, laser or mortar would hit during the tag-in i-frames
  (same test as Perfect Dodge; post-hit grace does not count).
- Effects: `perfect_swap_meter_gain` Special meter, `style_perfect_swap` style, the
  "PERFECT SWAP" callout, and the tag-in effect is upgraded (Rule 5).
- Shares `perfect_dodge_cooldown_sec` with Perfect Dodge so the two can't be chained
  for free meter.

### Rule 4 — Two kits

| | **Ayden** (power) | **Faith** (control) |
|---|---|---|
| Role | Close range, burst, crowd breaker | Long range, status, bullet control |
| Basic chain | Core Prana as a short-range arc / slam, ×`ayden_damage_mult` damage | Core Prana as a long-range bolt, ×`faith_damage_mult` damage |
| Reads grid column | Left column (Ayden's hand) adds damage | Right column (Faith's hand) adds status duration |
| Move speed | ×`ayden_speed_mult` (slightly slower) | ×`faith_speed_mult` (baseline) |
| Dash | Dash hits enemies it passes through (`ayden_dash_damage`) | Dash leaves a short slow-field for bullets (`faith_dash_field_sec`) |
| Perfect Cast bonus | Bigger hit, knock-back | Bigger bullet-cancel radius |
| Special flavour | Special detonates at a point in front (focused) | Special pulses around Faith (wide, longer status) |
| Tag-in effect | **Breach**: short shockwave, pushes enemies back | **Anchor**: slows bullets near Fayde for 1 s |

Status effects applied by either character stay on the enemy after a swap; that is the
bridge between the kits.

### Rule 5 — Hand-off combos
- **Tag-in on a status**: Ayden's first hit after swapping in deals
  ×`handoff_damage_mult` against an enemy carrying a status Faith applied.
- **Tag-in on damage**: Faith's first status after swapping in lasts
  ×`handoff_status_mult` on an enemy Ayden hit in the last 2 s.
- **Perfect Swap** doubles the tag-in effect's radius and duration.

### Rule 6 — The grid (Preparation)
- The grid is shared. Centre slot = core Prana for **both** characters (their basic chain
  and Special come from it).
- ADR-0057 changes meaning, not layout: the left column now empowers **Ayden's** attacks,
  the right column **Faith's**. The middle column (top and bottom) empowers both.
- "Hands touching" (both columns equal) now also shortens `swap_cooldown_sec` by
  `touch_swap_cooldown_mult`. The ×1.5 bonus stays.
- The prep preview shows two lines, one per character.

### Rule 7 — Shared resources
- **HP**: one shared bar (they are one body). See Open Question 2.
- **Special meter**: one shared meter. The Special fires as the active character's version.
- **Dash charges**: shared.

## 4. Formulas

`damage(hit) = base × tier × hands_power_mult(if Ayden) × char_damage_mult × handoff_mult × perfect_mult`

`status_duration = base × hands_control_mult(if Faith) × handoff_status_mult`

`hands_power_mult`, `hands_control_mult` come from `PranaHands.read()` (ADR-0057),
but each now applies only to its own character.

`effective_swap_cooldown = swap_cooldown_sec × (touch_swap_cooldown_mult if hands touching else 1)`

Starting values (to tune after playtest):
`ayden_damage_mult` 1.25, `faith_damage_mult` 0.85, `ayden_speed_mult` 0.92,
`handoff_damage_mult` 1.5, `handoff_status_mult` 1.5, `swap_cooldown_sec` 1.2,
`touch_swap_cooldown_mult` 0.7, `swap_iframe_sec` 0.2, `perfect_swap_meter_gain` 15.

## 5. Edge Cases
- Swap pressed on cooldown: ignored, portrait flashes.
- Swap mid-dash: the dash ends, the new character keeps the velocity for the rest of it,
  tag-in i-frames start.
- Swap on the frame Fayde dies: death wins, no swap.
- Preparation starts mid-swap: swap completes, cooldown resets for the next room.
- Grid with an empty left column: Ayden still fights at base damage (no hand bonus).
- A sigil or Heirloom that says "Fayde": applies to both characters.

## 6. Dependencies
Player Controller (active character, swap, i-frames), Spell Casting & Effects (two basic
chains), Special Attack (two flavours), Combination Resolution + PranaHands (column
meaning), Bullet Hell and Fast-Pace (Perfect Swap, style), Combat HUD (two portraits and
cooldown), Audio (swap and tag-in SFX), Art (a second character sprite set),
Memory Fragments (lore framing, Section 9).

## 7. Tuning Knobs
New `DuoTuning` resource (`assets/data/duo_tuning.tres`) with every value in Section 4,
plus `ayden_dash_damage`, `faith_dash_field_sec`, `perfect_swap_meter_gain`,
`style_perfect_swap`.

## 8. Acceptance Criteria
- Pressing Q in combat switches the active character, sprite and HUD portrait within one
  frame; pressing it again before the cooldown ends does nothing.
- Ayden's basic hits deal more damage at short range; Faith's reach further and apply
  longer status, using the same grid.
- Left-column Prana changes only Ayden's numbers; right-column only Faith's (unit tests on
  PranaHands + resolution).
- A bullet overlapping during tag-in i-frames counts as a Perfect Swap and adds meter.
- Ayden hitting an enemy Faith froze deals the hand-off bonus (unit test).
- HP, Special meter and dash charges are shared and survive swaps.

## 9. Lore (fits the existing story)
Fayde is built from Ayden's and Faith's Prana. His frame can let either brother's pattern
take the lead, and he flickers into that brother's shape while it does. Memo calls it
"letting one of them drive". Fragment 3 (Two Pairs of Hands) and Fragment 8 (Faith and
Ayden) already cover why both live in him; no fragment text has to change. The true
ending line gains weight: the player has been both of them the whole game.

## 10. Open Questions
1. **Who are the two characters?** (a) Fayde shifts into Ayden or Faith (this proposal),
   (b) Ayden and Faith as two separate beings, which rewrites the story, (c) Fayde plus a
   second character such as Memo.
2. **HP**: shared (this proposal, simplest and fits one body) or one bar each, where the
   resting character heals slowly (closer to Cloak & Dagger, more tactical, more UI).
3. **Art budget**: two full sprite sets, or one Fayde sprite with a colour/outline swap
   (red Ayden, blue Faith) for the first playable.
