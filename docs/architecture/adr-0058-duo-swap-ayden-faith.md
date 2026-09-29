# ADR-0058: Duo Swap — Ayden and Faith as Two Playable Brothers

## Status

Accepted (the user chose two separate brothers over one android that changes form,
2026-09-28)

## Date

2026-09-28

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The player controls Ayden or Faith in combat and swaps between them with one button,
like Cloak & Dagger in Marvel Rivals. Ayden hits harder at shorter range; Faith reaches
further and holds status longer. Each brother reads his own grid column (ADR-0057). A
swap has a cooldown, gives short i-frames and a tag-in effect, and the next attack can
cash in the other brother's setup (hand-off). Design: `design/gdd/duo-swap.md`.

## Decision

- Swap state and per-brother rules in `src/systems/duo_swap.gd` (`DuoSwap`, a
  RefCounted owned by PlayerController). Knobs in `assets/data/duo_tuning.tres`
  (`DuoTuning`).
- `PlayerController` owns the swap: `swap` action (Q / LB, rebindable), `try_swap()`,
  tag-in i-frames through `is_invincible()`, Perfect Swap through
  `register_perfect_dodge()` (it also emits `perfect_dodged`, so PaceDirector pays the
  same rewards and the cooldown is shared), Breach / Anchor tag-in effects, Faith's
  dash bullet cut, speed multiplier and the brother's sprite set. Emits
  `character_swapped` and `perfect_swapped`.
- `SpellCastingEffects` is told the active brother with `set_active_character()`.
  Step 8d applies Ayden's hand only for Ayden and the brother's damage weight; the
  core status uses Faith's hand only for Faith; cast range is scaled per brother; the
  hand-off bonus (Ayden on a status, Faith on an enemy Ayden just hit) is paid once
  per swap and emits `handoff_hit` (replaced by the Link Reaction, see amendment).
- `DuoSwap.NONE` (the SC&E default) keeps the pre-duo numbers, so tools and older
  tests that never create a player behave as before. PlayerController sets it back
  on `_exit_tree()`.
- HUD: one row in the left card ("AYDEN [Q] FAITH", or the cooldown), tinted per
  brother, plus "PERFECT SWAP" and "HAND-OFF" callouts.
- HP, Special meter and dash charges are shared.

### Amendment (2026-09-28): only Faith dashes

The user asked for each brother to have a clear strength and weakness, with only one
able to dash, so the fight itself pushes the player to swap.

- `DuoSwap.can_dash()`: Faith only (`NONE` keeps the pre-duo dash). PlayerController
  ignores dash input as Ayden, spends no charge, and emits `dash_blocked`; CombatHUD
  shows "SWAP TO DASH" and hides the dash ring while Ayden is out. Charges keep
  recharging while he is out.
- Ayden's dash hit is removed (`ayden_dash_damage`, `ayden_dash_hit_radius` dropped).
- Ayden is sturdy instead: HealthAndDamage step 5c multiplies damage to the player by
  `get_incoming_damage_mult()` (`ayden_damage_taken_mult`, 0.75), and
  `request_knockback()` scales by `ayden_knockback_mult` (0: no stagger).
- `swap_cooldown_sec` 1.2 → 0.6 (the swap is Ayden's escape), `ayden_damage_mult`
  1.25 → 1.15 (he is tougher now).
- Assist auto-dash swaps Ayden out instead of dashing. The guided first room starts
  with Faith because its lessons teach the dash.

### Amendment (2026-09-28): palm faces, Link Reaction, heartbeat

The user asked for a reason to swap that only this game could have, built on the Prana
grid. Three rules, all in `DuoTuning`:

- **Palm faces.** `DuoSwap.face()` trades a brother's palm slot (3 Ayden, 5 Faith) with
  the centre. `CombinationResolution._attach_faces()` resolves both faces on combat start
  into `SpellEffect.faces`. SC&E keeps the grid's own effect as `_base_spell_effect` and
  casts the active brother's face; `set_active_character()` switches it and emits
  `face_changed` (not `cast_started`, which counts casts). CombatHUD reads the face for
  its recognition banner; the prep preview adds a duo line (`SpellPreview.duo_line`).
  A pure mirror was rejected: grid adjacency is symmetric, so it changes nothing.
- **Link Reaction** replaces the hand-off bonuses (`handoff_*`, `ayden_mark_sec`,
  `handoff_hit` removed). SC&E step 9b `_link_hit()` keeps one mark per enemy (brother,
  element, time); the other brother's different element fires `_fire_link_reaction()`:
  burst damage through `_deal_bonus_damage()` (no marks, no chaining), both elements'
  plain statuses, meter, `link_reaction` and `reaction_triggered` (name from
  `CombinationResolution.get_reaction()`).
- **Heartbeat.** `DuoSwap` keeps a beat clock (reset each preparation). `try_swap()`
  records whether it landed within `resonance_window_sec` of a beat; PlayerController
  passes it to `set_active_character(c, true, resonant)` and emits `resonated`. SC&E
  grants a free Perfect, meter, and a pending reaction with the benched brother's
  element. CombatHUD pulses the duo row's alpha with `get_heartbeat_phase()`.

## Alternatives Considered

- **One android that changes form.** Kept the story as written, but the user chose two
  separate brothers.
- **Separate HP per brother.** Closer to the reference and more tactical, but it needs
  a second bar, death rules for one brother, and a heal-while-resting rule. Deferred
  (duo-swap.md Open Question 2).
- **Keep both grid hands for both brothers.** Simpler, but then the columns stop
  meaning anything once the brothers are playable.

## Consequences

- Swapping ends the current basic chain; the other brother starts his own.
- Q is shared with the prep grid's discard key; the two never run at the same time.
- Faith's dash wipes bullets like the dash-cut sigil (the larger radius wins), so the
  sigil is weaker on Faith. Balance pass needed.
- Sprites: each brother has his own sheet set on the shared player rig (Fayde's pre-duo rig) (body, glow, five Prana
  cast poses, crumple), made by `tools/art-gen/generate_character_sprites.gd`.
  `DuoLooks` (`src/visual/duo_looks.gd`) swaps them on PixelCharacter and the crumple
  pose. Ayden: spiky auburn hair, red headband, rust vest, wrapped forearms. Faith:
  dark hair with a ponytail, lens, slate long coat, teal sash. The main menu shows
  both brothers side by side (UI pass, below).
- Story rewrite (fragments 1, 8, 9, true ending, UI text naming "Fayde"): done
  2026-09-28, see the amendments below. Design and architecture docs were brought in
  line on 2026-09-29.
- Tests: `tests/unit/duo-swap/duo_swap_test.gd`, `tests/unit/duo-swap/duo_link_test.gd`.

## Amendment 2026-09-28 — Link Burst, severed link, duo sigils, style, tutorial

- **Link Burst.** `_trigger_special()` calls `_try_link_burst()` after the Special's own
  hits. `duo_cores()` returns both brothers' face elements when they differ; the burst
  deals `_deal_bonus_damage()` in `link_burst_radius()`, applies both plain statuses,
  pulls on Voidblue, Regenerates on Verdant, and emits `link_burst`. PlayerController
  answers with `show_partner()`: a throwaway PixelCharacter in the benched brother's
  sheets that casts beside the active brother and fades. This replaces per-brother Specials.
- **Severed link.** `BossPhaseEvent.sever_link` (Cipher Keeper phase 2). BossDirector
  calls `PlayerController.sever_link()`; `DuoSwap.sever()` makes `can_swap()` false until
  `note_hit()` has counted `sever_reconnect_hits` `spell_hit_element` hits. Then
  `relinked` fires and the meter is paid. `reset_timers()` clears it.
- **Duo sigils.** SC&E keeps run-scoped `_link_radius_mult` and
  `_resonance_meter_mult` (reset with the run damage multiplier); DuoSwap keeps
  `_beat_mult`. Echo Brother lives in SigilEffects on SC&E's new `brother_tagged_in`
  signal and calls `echo_strike()`, which writes the leaving brother's Link mark.
  Wide Link and Echo Brother are Heirlooms (12 in total, 4 per row).
- **Style and run log.** PaceDirector listens to `character_swapped`, `resonated`,
  `link_reaction` and `link_burst`, adds style, tallies each fight and emits
  `duo_counted`; the game loop writes it on the fight's build and `RunLog.duo_totals()`
  sums the run.
- **Tutorial.** TutorialRoom gained the palm, swap, link and resonance lessons with
  adapters for those signals; PranaGridSlot draws a palm ring (`palm_owner_of()`).

## Amendment 2026-09-28 (2) — duo foes, duo music, duo Cores, story

- **Duo foes.** `DuoFoe` (`src/systems/duo_foe.gd`) holds the pure rules. WaveManager
  rolls a `duo_foe` per composition entry on its own RNG (seeded from the wave RNG
  after the composition) and calls `EnemyInstance.make_duo_foe()`. HealthAndDamage step
  5d asks the enemy `take_duo_hit(character)` for DIRECT hits (character from
  `_duo_character_provider`, SpellCastingEffects by default), scales the damage (min 1)
  and emits `duo_foe_hit` for the HUD callout. Flitting foes hop with `apply_knockback`.
- **Duo music.** `DuoMusic` (`src/audio/duo_music.gd`), run-scoped, adds two named shelf
  filters to the Music bus (idempotent) and a synthesised `AudioStreamWAV` thump on the
  SFX bus; it listens to `character_swapped`, the new `PlayerController.heartbeat` and
  `link_burst`. AudioSystem is untouched.
- **Duo Cores.** `CoreFrame` gained per-brother damage, swap cooldown and Link reach
  multipliers; SC&E keeps `_brother_damage_mult` (reset with the run damage mult),
  DuoSwap `_cooldown_mult`.
- **Story.** `story_config.tres` fragments 1, 8, 9 and both endings rewritten for two
  brothers sharing one core; Fayde is the link.
- Tests: `tests/unit/duo-swap/duo_world_test.gd`.

## Evidence

`production/qa/evidence/adr0058-duo-ayden.png`, `adr0058-duo-faith.png` and
`adr0058-duo-sprites-closeup.png` (own sprite sets).
