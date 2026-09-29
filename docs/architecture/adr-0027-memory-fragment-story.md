# ADR-0027: Memory Fragment Story and Endings

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The duo's story is told through ten memory fragments recovered in a fixed order
across runs, plus two endings after the Cipher Keeper. The story is data
(`assets/data/story/story_config.tres`), the rules are a stateless `StoryRules`
class, and the count of recovered fragments is saved in `MetaProgress`
(`user://progress.cfg`). A full-screen `MemoryFragmentModal` shows each fragment
and ending; a `MemoriesPanel` on the main menu re-reads them.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Narrative / UI / Persistence |
| **Knowledge Risk** | LOW: `Resource`, typed `Array[Resource]` exports, `ConfigFile`, `CanvasLayer`, `SceneTree.paused`, all unchanged since 4.0. No 4.4+ APIs. |

## Context

The game concept promises a narrative roguelike where "the dungeon remembers what
you forgot", but until now the only narrative hook was a placeholder modal on
anchor objects that never spawn in the real run. The run also ended on a stat
screen with no ending. And the main menu's Play button loaded `demo.tscn`, a
one-floor build, so Floors 2 and 3 and the Cipher Keeper were not reachable from
the menu at all.

## Decision

1. **Fixed order, counted progress.** Fragments unlock strictly in story order, so
   every player reads the same story front to back. Progress stores only
   `fragments_found` (an int), not a set of ids, so reordering or rewriting a
   fragment never corrupts a save.
2. **Beats.** A cleared floor, a win, and a death that cleared at least
   `death_unlock_min_rooms` rooms each recover the next fragment. Deaths count so
   losing still moves the story (Hades-style), with a room minimum so an instant
   death is not a shortcut. All four rules are toggles or numbers in `StoryConfig`.
3. **Endings.** A win on `ending_min_floor` (3) or later plays an ending after the
   win's fragment: the partial ending, with a "N of 10 recovered" line, or the true
   ending once all ten are found. The one-floor demo scene never plays an ending.
4. **Presentation.** One card class (`MemoryFragmentModal`) serves fragments,
   endings and anchor objects. It pauses the tree, ignores input for 0.6 s so a
   held cast cannot skip it, and restores the previous pause state when it closes
   or is freed. The run loop `await`s the card before loading the next floor or
   building the run summary.
5. **Text location.** Story prose lives in the `StoryConfig` resource, because it is
   content, not UI chrome, and a translator will want it as one file. Every UI
   string around it (headers, hints, archive labels) goes through `UICopy`.
6. **Play loads the full run.** `main_menu.gd` now loads `main.tscn` (three floors).
   `demo.tscn` stays for a short demo build.

## Alternatives Considered

- **Random fragment per beat** (the concept doc's open question). Rejected: with
  ten fragments that build to a twist, reading them out of order gives the twist
  away. Fixed order with several beats per run already keeps them coming.
- **Memory Chamber rooms with anchor objects.** Kept for later: it needs a new room
  type, art and placement. The anchor path still works and now shows the story
  fragment when its `memory_id` matches one.
- **Prose in `UICopy`.** Rejected: 12 long multi-paragraph strings would drown the
  UI copy file and mix content with interface text.

## Consequences

- A player who wins every run sees the true ending on their fourth win at the
  earliest (3 fragments per winning run, 10 needed before the ending plays).
- Old `progress.cfg` files load with `fragments_found = 0`; no version bump needed.
- Adding fragments later only means appending to `story_config.tres`; players who
  had the true ending simply see new "? ? ?" entries in the archive.

## Validation

`tests/unit/story/` covers the beat rules, lookups, endings, save round-trip,
old-save compatibility, the card (pause, grace period, close) and the archive.
