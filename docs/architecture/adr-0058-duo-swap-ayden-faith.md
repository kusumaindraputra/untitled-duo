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
  same rewards and the cooldown is shared), Breach / Anchor tag-in effects, Ayden's dash
  hit, Faith's dash bullet cut, speed multiplier and the brother's sprite set. Emits
  `character_swapped` and `perfect_swapped`.
- `SpellCastingEffects` is told the active brother with `set_active_character()`.
  Step 8d applies Ayden's hand only for Ayden and the brother's damage weight; the
  core status uses Faith's hand only for Faith; cast range is scaled per brother; the
  hand-off bonus (Ayden on a status, Faith on an enemy Ayden just hit) is paid once
  per swap and emits `handoff_hit`.
- `DuoSwap.NONE` (the SC&E default) keeps the pre-duo numbers, so tools and older
  tests that never create a player behave as before. PlayerController sets it back
  on `_exit_tree()`.
- HUD: one row in the left card ("AYDEN [Q] FAITH", or the cooldown), tinted per
  brother, plus "PERFECT SWAP" and "HAND-OFF" callouts.
- HP, Special meter and dash charges are shared.

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
- Sprites: each brother has his own sheet set on Fayde's rig (body, glow, five Prana
  cast poses, crumple), made by `tools/art-gen/generate_character_sprites.gd`.
  `DuoLooks` (`src/visual/duo_looks.gd`) swaps them on PixelCharacter and the crumple
  pose. Ayden: spiky auburn hair, red headband, rust vest, wrapped forearms. Faith:
  dark hair with a ponytail, lens, slate long coat, teal sash. The main menu still
  shows Fayde.
- Not yet done: brother-specific Specials, the
  story rewrite (fragments 1, 8, 9, true ending, UI text naming "Fayde").
- Tests: `tests/unit/duo-swap/duo_swap_test.gd`.

## Evidence

`production/qa/evidence/adr0058-duo-ayden.png`, `adr0058-duo-faith.png` and
`adr0058-duo-sprites-closeup.png` (own sprite sets).
