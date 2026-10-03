# ADR-0059: Story Removed — Heirlooms Gated by Runs Played

## Status

Accepted (the user removed all story content as the first step of the shadow-forms
concept change, 2026-10-03). Supersedes ADR-0027; amends ADR-0030 (Heirloom gates).

## Date

2026-10-03

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The game is changing concept: the player becomes a shadow that shifts into many forms
and picks two per run. All story goes, first. The memory fragments, both endings, the
Memories archive and the memory anchors are deleted. Heirlooms that were revealed by
recovered memories are now revealed by runs played, with the same gate numbers.

## Decision

- Deleted: `StoryRules`, `StoryConfig`, `MemoryFragment`, `story_config.tres`,
  `MemoryFragmentModal`, `MemoriesPanel`, `AnchorObject`, `AnchorObjectNode` and the
  anchor data, `design/gdd/memory-fragments.md`, `design/anchor-objects.md`, and their
  tests.
- `MetaProgress` no longer holds `fragments_found`, `ending_seen` or
  `true_ending_seen`. Older `progress.cfg` files still load; the old keys are ignored.
- `MetaTuning.heirloom_memory_gates` becomes `heirloom_run_gates` (same values,
  0/3/6/9) and `memories_needed()` becomes `runs_needed()`. `MetaProgress.is_revealed()`
  compares `runs` (won or lost). The run summary still names Heirlooms a run reveals.
- The game loop no longer shows a card on a floor clear, death or win. The main menu
  loses the Memories button; its records line shows runs played instead of memories.
  The run summary loses the memories line.
- The run save writes `runs_at_start` instead of `fragments_at_start`.

## Alternatives Considered

- Gate Heirlooms by bosses beaten: closer to "earned", but a new player who never
  beats a boss would never see a new Heirloom. Runs played keeps the old pacing (a run
  used to recover at least one memory).
- Remove the gates: shows all twelve Heirlooms at once, too much for a first menu.

## Consequences

- Ayden, Faith, the duo tagline and "Cipher" names stay until the forms refactor and
  the rename; the severed-link boss phase stays as a mechanic without its story beat.
- Docs that still mention memories (game concept, duo swap Section 9, UX docs) are
  history until the concept GDD is rewritten.

## Evidence

- `tests/unit/meta-progression/heirloom_run_gate_test.gd` (gates, old save loads).
- Full headless suite green: 2089 cases (was 2141; the story suites are gone).

## Amendment 2026-10-03 — working title and shadow names

The user named the game "Untitled" for now and asked for "Cipher" to become shadow
themed. Player-facing text only; code identifiers (`cipher_*`, `CoreFrame`,
`enemy_cipher_keeper.tres`) stay until the forms refactor.

| Was | Now |
|---|---|
| The Last Cipher (title, project name, export names) | Untitled |
| Cipher Shards | Shade Shards |
| Cipher Core(s), floor 3 "Cipher Core" | Shadow Core(s), "Shadow Core" |
| Cipher Keeper (final boss) | Shade Keeper |
| Sharpened Cipher (sigil) | Sharpened Shade |
| Keeper phase banners "SEPARATION IS THE WEAPON", "THE LAST CIPHER" | "THE LINK IS CUT", "THE LAST SHADE" |
