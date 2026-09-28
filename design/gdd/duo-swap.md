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
is Faith's. This proposal turns those two hands into two playable characters. Three
rules make the swap the heart of the fight rather than a button: each brother casts the
Prana in his own palm (the grid has two faces), the two brothers' elements react on an
enemy (Link Reaction), and a swap on their shared heartbeat Resonates.

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

### Rule 5 — Link Reaction (replaces the hand-off bonuses, 2026-09-28)
- Every hit a brother lands leaves his element (his core Prana, Rule 6) on the enemy for
  `link_mark_sec`.
- When the **other** brother hits that enemy with a **different** element, the two react:
  a **Link Reaction**. It uses the Prana Reaction Matrix names (combination-resolution.md
  Formula 9), e.g. Ashfire + Deepfrost = Thermal Shock, Stormgold + Voidblue = Short
  Circuit.
- The burst: `link_damage_mult` × base spell damage on the enemy, ×`link_splash_mult` on
  other enemies within `link_radius`, both elements' statuses for `link_status_sec` on
  everyone it hits (Burn, Blind, Stun at a third, Freeze; Verdant regenerates Fayde
  instead), and `link_meter_gain` Special meter. "LINK!" and the reaction's name pop up.
- The hit then leaves its own element, so swapping back and hitting again reacts again.
  That back-and-forth is the core duo loop.
- Same element on both brothers, or the same brother hitting twice, never reacts.
- Bonus damage (reactions, Cascade, the burst itself) does not leave marks.

### Rule 6 — The grid: palm faces (Preparation)
- The grid is shared and has **two faces**. Each brother holds a palm: Ayden the
  middle-left slot, Faith the middle-right. In combat the active brother's palm Prana
  trades places with the centre and becomes **his core**, so his basic chain, tier,
  modifiers, grid reactions and Cascade come from his own face of the grid.
- An empty palm keeps the centre as that brother's core. `palm_faces` off = both cast the
  centre (the first-pass rule).
- A swap switches to the incoming brother's face at once (the chain restarts).
- ADR-0057 still holds: the left column empowers **Ayden's** attacks, the right column
  **Faith's**. A face never changes how many Prana each hand holds.
- "Hands touching" (both columns equal) now also shortens `swap_cooldown_sec` by
  `touch_swap_cooldown_mult`. The ×1.5 bonus stays.
- The prep preview adds a duo line: "AYDEN <core> · FAITH <core> → LINK: <reaction>".
  Building the grid is now also choosing which Link Reaction the brothers will make.
- A pure left-right mirror was considered and dropped: adjacency is symmetric, so a mirror
  changes no reaction, Cascade or spell.

### Rule 6b — Shared heartbeat (Resonance)
- The brothers' shared core beats every `heartbeat_sec` from the start of combat. The
  HUD duo row ("♥ AYDEN [Q] FAITH") glows on each beat.
- A swap within `resonance_window_sec` of a beat **Resonates**: "RESONANCE" pops up, the
  next basic cast is Perfect whatever its timing (`resonance_perfect_sec`), the Special
  meter gains `resonance_meter_gain`, and the next landed hit sets off a Link Reaction
  with the benched brother's element even if the enemy carries no mark.
- The window is generous on purpose (young players); it is a skill layer, not a gate.

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

`damage(hit) = base × tier × hands_power_mult(if Ayden) × char_damage_mult × perfect_mult`
(base, tier from the active brother's face, Rule 6)

`status_duration = base × hands_control_mult(if Faith)`

`link_burst = 20 × link_damage_mult × run_damage_mult` on the reacting enemy,
`× link_splash_mult` on others within `link_radius`

`resonant(swap) = distance(combat_clock, nearest multiple of heartbeat_sec) ≤ resonance_window_sec`

`hands_power_mult`, `hands_control_mult` come from `PranaHands.read()` (ADR-0057),
but each now applies only to its own character.

`damage_taken = incoming × player_damage_mult × (ayden_damage_taken_mult if Ayden)`

`effective_swap_cooldown = swap_cooldown_sec × (touch_swap_cooldown_mult if hands touching else 1)`

`cast_range = type_range × (ayden_range_mult | faith_range_mult)`

Starting values (to tune after playtest):
`ayden_damage_mult` 1.15, `faith_damage_mult` 0.85, `ayden_range_mult` 0.85,
`faith_range_mult` 1.45, `ayden_speed_mult` 0.92, `ayden_damage_taken_mult` 0.75,
`ayden_knockback_mult` 0.0, `link_mark_sec` 3.0, `link_damage_mult` 1.5 (30 damage),
`link_radius` 60, `link_splash_mult` 0.5, `link_status_sec` 1.5, `link_meter_gain` 12,
`heartbeat_sec` 1.0, `resonance_window_sec` 0.15, `resonance_perfect_sec` 1.5,
`resonance_meter_gain` 10, `swap_cooldown_sec` 0.6, `touch_swap_cooldown_mult` 0.7,
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
- Both palms empty: both brothers cast the centre, so no Link Reaction is possible. The
  prep preview's duo line shows the same core twice, which is the hint to fill a palm.
- The enemy dies from the hit that reacts: the burst still lands on the others nearby.
- Resonance while the next hit misses: the pending reaction waits for the next hit that
  lands (until the room ends).
- The first swap of a room at the very start of combat lands on a beat (the clock starts
  at 0) and Resonates. Accepted: it rewards opening with a swap.

## 6. Dependencies
Player Controller (active character, swap, i-frames), Spell Casting & Effects (two basic
chains), Special Attack (two flavours), Combination Resolution + PranaHands (column
meaning), Bullet Hell and Fast-Pace (Perfect Swap, style), Combat HUD (two portraits and
cooldown), Audio (swap and tag-in SFX), Art (a second character sprite set),
Memory Fragments (lore framing, Section 9).

## 7. Tuning Knobs
`DuoTuning` resource (`assets/data/duo_tuning.tres`) with every value in Section 4, plus
`faith_dash_cut_radius` (24 px), `breach_knockback` (60 px) and `palm_faces` (on).
Safe ranges are on each export in `src/data/duo_tuning.gd`.

## 8. Acceptance Criteria
- Pressing Q in combat switches the active character, sprite and HUD portrait within one
  frame; pressing it again before the cooldown ends does nothing.
- Ayden's basic hits deal more damage at short range; Faith's reach further and apply
  longer status, using the same grid.
- Left-column Prana changes only Ayden's numbers; right-column only Faith's (unit tests on
  PranaHands + resolution).
- A bullet overlapping during tag-in i-frames counts as a Perfect Swap, once per swap.
- With Deepfrost in Ayden's palm and Voidblue in the centre, Ayden casts Deepfrost and
  Faith Voidblue; the swap switches the spell (unit test).
- Faith hitting an enemy Ayden hit within `link_mark_sec` with another element fires one
  Link Reaction named by the Reaction Matrix; same element or same brother never reacts
  (unit tests).
- A swap on a heartbeat Resonates: free Perfect, meter, and the next hit reacts with the
  benched brother's element (unit tests).
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
