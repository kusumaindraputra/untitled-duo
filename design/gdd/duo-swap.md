# Duo Swap — Ayden and Faith

> **Status**: Implemented, first pass (2026-09-28, ADR-0058; only Faith dashes since the
> same day) — needs playtest tuning
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
the arena; the other steps out of the fight and waits in the Prana link between them. They share one HP bar, one Special meter
and one Prana grid, but they read that grid differently and fight differently: Ayden is
close range, heavy hits, sturdy and cannot dash; Faith is long range, status and bullet
control, and the only one who dashes. Each has a clear strength and a clear weakness, so
the fight itself asks for the swap: Ayden wades in, and when the bullets get too thick
the player swaps to Faith and dashes out.
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

The story payoff: two brothers whose Prana only works together, climbing side by side,
and every swap is them trusting each other with the fight.

## 3. Detailed Rules

### Rule 1 — One active character
- Combat starts with the character chosen at the end of Preparation (default: whoever was
  active last room; first room of a run: Ayden).
- Only the active character moves, casts and has a hurtbox. The inactive one is not in the
  arena and cannot be hit.
- Movement, graze, orbs and style work the same for both (bullet-hell.md,
  fast-pace.md). Only Faith dashes (Rule 4). Tuning differences are in Rule 4.

### Rule 2 — Swap
- `swap` action: **Q**, gamepad **LB** (rebindable). Allowed in COMBAT_PHASE while ENABLED
  or DASHING. Q also discards a grid slot, but only during Preparation.
- Swap is instant and keeps position, velocity and facing. The current basic chain ends.
- Cooldown `swap_cooldown_sec` (default 0.6 s, short because the swap is Ayden's only way
  out). The HUD shows it on the portrait.
- **Tag-in**: the character swapping in grants `swap_iframe_sec` (0.2 s) of i-frames and
  fires a small tag-in effect (Rule 5).
- Swapping during the Special's lock is allowed but does not cancel the Special.
- Swapping mid-dash keeps the dash, even when Ayden tags in; the tag-in i-frames start on
  top of it.

### Rule 3 — Perfect Swap
- Counts when an enemy bullet, laser or mortar would hit during the tag-in i-frames
  (same test as Perfect Dodge; post-hit grace does not count).
- For Ayden this is the Perfect Dodge he cannot do himself: swap to Faith as the bullet
  arrives.
- Effects: the tag-in effect fires again at ×`perfect_swap_tag_in_mult` radius and push.
- Shares `perfect_dodge_cooldown_sec` with Perfect Dodge so the two can't be chained
  for free meter. It pays the Perfect Dodge rewards (meter, free Perfect Cast, slow-mo,
  style) and shows "PERFECT SWAP".

### Rule 4 — Two kits

| | **Ayden** (power) | **Faith** (control) |
|---|---|---|
| Role | Close range, burst, crowd breaker | Long range, status, bullet control |
| Basic chain | Core Prana as a short-range arc / slam, ×`ayden_damage_mult` damage | Core Prana as a long-range bolt, ×`faith_damage_mult` damage |
| Reads grid column | Left column (Ayden's hand) adds damage | Right column (Faith's hand) adds status duration |
| Move speed | ×`ayden_speed_mult` (slightly slower) | ×`faith_speed_mult` (baseline) |
| Dash | **Cannot dash.** Pressing dash pops "SWAP TO DASH"; his way out is a swap to Faith | The only one who dashes; the dash wipes bullets it passes (`faith_dash_cut_radius`) |
| Toughness | Takes ×`ayden_damage_taken_mult` damage, knock-back ×`ayden_knockback_mult` (0: never staggers) | Takes full damage and knock-back |
| Special flavour | *Not yet: the Special is shared for now* | *Not yet* |
| Tag-in effect | **Breach**: pushes enemies within `tag_in_radius` back | **Anchor**: wipes enemy bullets within `tag_in_radius` |

Status effects applied by either character stay on the enemy after a swap; that is the
bridge between the kits.

### Rule 5 — Hand-off combos
- **Tag-in on a status**: Ayden's first landed attack within `handoff_window_sec` of
  swapping in deals ×`handoff_damage_mult` against an enemy carrying Burn, Blind, Stun,
  Freeze or Chill.
- **Tag-in on damage**: Faith's first landed attack within `handoff_window_sec` of
  swapping in holds its status ×`handoff_status_mult` on an enemy Ayden hit within
  `ayden_mark_sec`.
- The first attack that lands after a swap closes the window, bonus or not.

### Rule 6 — The grid (Preparation)
- The grid is shared. Centre slot = core Prana for **both** characters (their basic chain
  and Special come from it).
- ADR-0057 changes meaning, not layout: the left column now empowers **Ayden's** attacks,
  the right column **Faith's**. The middle column (top and bottom) empowers both.
- "Hands touching" (both columns equal) now also shortens `swap_cooldown_sec` by
  `touch_swap_cooldown_mult`. The ×1.5 bonus stays.
- The prep preview shows two lines, one per character.

### Rule 7 — Shared resources
- **HP**: one shared bar, carried by the Prana link that binds them (if one falls, the
  link breaks and both fall). See Open Question 2.
- **Special meter**: one shared meter. The Special fires as the active character's version.
- **Dash charges**: Faith's. They keep recharging while Ayden is out, so a swap to Faith
  usually finds a charge ready. The HUD dash ring hides while Ayden is out.
- **Assist auto-dash (F2)**: as Ayden it swaps to Faith instead (tag-in i-frames let the
  bullet pass); as Faith it dashes as before.
- **Guided first room** (ADR-0055) starts with Faith, because its lessons teach the dash.

## 4. Formulas

`damage(hit) = base × tier × hands_power_mult(if Ayden) × char_damage_mult × handoff_mult × perfect_mult`

`status_duration = base × hands_control_mult(if Faith) × handoff_status_mult`

`hands_power_mult`, `hands_control_mult` come from `PranaHands.read()` (ADR-0057),
but each now applies only to its own character.

`damage_taken = incoming × player_damage_mult × (ayden_damage_taken_mult if Ayden)`

`effective_swap_cooldown = swap_cooldown_sec × (touch_swap_cooldown_mult if hands touching else 1)`

`cast_range = type_range × (ayden_range_mult | faith_range_mult)`

Starting values (to tune after playtest):
`ayden_damage_mult` 1.15, `faith_damage_mult` 0.85, `ayden_range_mult` 0.85,
`faith_range_mult` 1.45, `ayden_speed_mult` 0.92, `ayden_damage_taken_mult` 0.75,
`ayden_knockback_mult` 0.0, `handoff_damage_mult` 1.5,
`handoff_status_mult` 1.5, `swap_cooldown_sec` 0.6, `touch_swap_cooldown_mult` 0.7,
`swap_iframe_sec` 0.2, `tag_in_radius` 70, `perfect_swap_tag_in_mult` 2.0.

Example: Voidblue T1, Ayden, one Prana in his hand: `20 × 0.9 × 1.0 × 1.06 × 1.15 = 21.9`.
The same cast as Faith: `20 × 0.9 × 0.85 = 15.3`, but Blind lasts `2.0 × control_mult`.

## 5. Edge Cases
- Swap pressed on cooldown: ignored, portrait flashes.
- Swap mid-dash: the new character keeps the dash and its velocity for the rest of it
  (Ayden too), tag-in i-frames start.
- Dash pressed as Ayden: no dash, no charge spent, "SWAP TO DASH" pops above him.
- Swap on cooldown while Ayden is cornered: he has no escape but his toughness. This is
  the intended cost of staying Ayden too long; `swap_cooldown_sec` is the knob if it
  feels unfair.
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
`DuoTuning` resource (`assets/data/duo_tuning.tres`) with every value in Section 4, plus
`faith_dash_cut_radius`
(24 px), `breach_knockback` (60 px), `handoff_window_sec` (2 s), `ayden_mark_sec` (2 s).
Safe ranges are on each export in `src/data/duo_tuning.gd`.

## 8. Acceptance Criteria
- Pressing Q in combat switches the active character, sprite and HUD portrait within one
  frame; pressing it again before the cooldown ends does nothing.
- Ayden's basic hits deal more damage at short range; Faith's reach further and apply
  longer status, using the same grid.
- Left-column Prana changes only Ayden's numbers; right-column only Faith's (unit tests on
  PranaHands + resolution).
- A bullet overlapping during tag-in i-frames counts as a Perfect Swap, once per swap.
- Ayden hitting an enemy Faith froze deals the hand-off bonus (unit test).
- HP, Special meter and dash charges are shared and survive swaps.
- Dash pressed as Ayden does nothing but emit `dash_blocked`; as Faith it dashes (unit test).
- Ayden takes ×`ayden_damage_taken_mult` damage and no knock-back; Faith takes both in
  full (unit test).
- Assist auto-dash swaps Ayden out instead of dashing (unit test).

## 9. Lore — Ayden and Faith as two separate beings (chosen 2026-09-28)

The user chose to make Ayden and Faith two separate characters instead of one android
built from both. This changes the premise, so the story needs a rewrite pass before
content work. Proposed default, open to change:

- **Premise**: the father could not save the brothers' bodies, so he rebuilt each of them
  as a small android, one frame per brother, holding their own memories and Prana. The
  two frames share one Prana core that only runs when both are awake and linked. That
  link is named **Fayde** (Faith + Ayden), so the name and the title stay, but Fayde is
  now the bond, not a person.
- **Why they swap**: the shared core can only drive one frame at full power at a time.
  The other stays close and linked, ready to take over. This is the in-world reason for
  the swap button and the shared HP and Special meter.
- **Memo** stays the companion and caretaker (their original caretaker in the backstory).
- **Grid**: unchanged meaning from ADR-0057, left hand Ayden, right hand Faith.
- **Ending**: the true ending line "You're both of them. And you're you." no longer fits.
  A replacement in the same spirit: the brothers learn the link is what the First King
  wanted to break ("Separation is the weapon", fragment 6), and they choose to stay linked.

### What has to change
| Area | Change |
|------|--------|
| `design/gdd/game-concept.md` | Premise: two android brothers linked as Fayde, not one boy |
| `design/gdd/memory-fragments.md` + `assets/data/story/story_config.tres` | Rewrite fragments 1, 8, 9 and the true ending (TE); voices "Fayde" become Ayden or Faith. Fragments 2–7 and 10 mostly keep their content |
| UI text (`combat_hud.gd`, `tutorial_coach.gd`, `run_summary_panel.gd` and others) | "Fayde" as the player's name becomes the active brother's name |
| Art | Done 2026-09-28: two sprite sets on Fayde's rig (ADR-0058). Main menu backdrop still shows Fayde |
| Main menu tagline | "Two brothers' Prana. One pair of hands." becomes e.g. "Two brothers. One link." |

## 10. Open Questions
1. ~~Who are the two characters?~~ Decided 2026-09-28: Ayden and Faith as two separate
   beings (Section 9).
2. **HP**: shared (this proposal, simplest, explained by the link) or one bar each, where the
   resting character heals slowly (closer to Cloak & Dagger, more tactical, more UI).
3. ~~**Art budget**~~ Decided 2026-09-28: two full sprite sets, generated on Fayde's rig.
