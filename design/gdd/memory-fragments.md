# Memory Fragments and Endings

> **Status**: Implemented (ADR-0027) · **Code**: `src/systems/story_rules.gd`,
> `src/ui/memory_fragment_modal.gd`, `src/ui/memories_panel.gd` ·
> **Data**: `assets/data/story/story_config.tres`

## Overview

Ayden and Faith recover their past one memory at a time. Ten fragments unlock in
story order across runs, from the old man pushing them into the dark back to who the
two boys were, why they were rebuilt as two small frames sharing one core, and why
that link is called Fayde (rewritten 2026-09-28 for the duo, ADR-0058). Beating the Cipher Keeper plays an ending; recovering all
ten first unlocks the true ending.

## Player Fantasy

"I remembered something, and it changed everything." Every floor cleared, and even
a hard-fought death, gives back a piece of who the brothers are, so each run moves the story
forward.

## Detailed Rules

| Beat | Recovers the next fragment when |
|------|--------------------------------|
| Floor boss defeated (not the last floor) | always |
| The brothers fall (shared HP reaches 0) | the run cleared at least 3 rooms |
| Final boss defeated | always, then the ending plays |

- Fragments unlock in the fixed order below; progress is a count saved between runs.
- When all ten are found, beats recover nothing more.
- The ending plays after a win on Floor 3: the partial ending while fragments are
  missing (with "N of 10 memories recovered"), the true ending once all ten are found.
- The card pauses the game, ignores input for 0.6 s, then any key, click or pad
  button continues.
- Main menu → Memories lists all ten (locked ones as "? ? ?") and any ending seen.

### The story, in order

| # | Title | Voice | What it reveals |
|---|-------|-------|-----------------|
| 1 | The Push | Faith | The only memory they woke with; a hand found hers in the dark |
| 2 | Don't Be Lonely | Memo | Memo's handwritten panel and the man who wrote it |
| 3 | Two Pairs of Hands | ? | Two boys whose Prana works only together |
| 4 | Each Symbol Is a Breath | Father | The 3×3 grid lesson (ties to the Prana grid) |
| 5 | The Kind Stranger | Faith | The robot disguised as a human |
| 6 | Separation | Ayden | Separation is the weapon |
| 7 | Signatures Extinguished | Kingdom Record | The final touch and transmission |
| 8 | Faith and Ayden | Father | Two frames, one core; FAITH + AYDEN crossed down to FAYDE, "the link" |
| 9 | Father | Ayden | The brothers' first word, one heartbeat between two chests |
| 10 | The Hatch | Father | The raid; loops back to fragment 1 |
| E | The Surface | Faith | Partial ending: keep climbing, together |
| TE | Fayde | Ayden and Faith | True ending: separation was the Kingdom's weapon; "Two of you, one heartbeat." Fayde is the link, and it means help |

## Formulas

`fragments per winning run = 2 floor clears + 1 win = 3`
`earliest true ending = ceil(10 / 3) = 4 winning runs` (sooner counting deaths).

## Edge Cases

- Win on the one-floor demo scene: counts as a win beat but plays no ending.
- Quitting mid-run keeps fragments already recovered (saved at once).
- Card freed without being closed (scene change): the pause state is restored.
- Anchor object with an unknown `memory_id`: shows a short "A Memory Stirs" card.

## Dependencies

MetaProgress (save), GameStateManager (`floor_completed`, `run_ended`),
RunManager (rooms cleared, floor reached), UICopy, main menu.

## Tuning Knobs

In `story_config.tres`: `unlock_on_floor_clear`, `unlock_on_death`,
`death_unlock_min_rooms` (3), `unlock_on_win`, `ending_min_floor` (3).

## Acceptance Criteria

- Clearing Floor 1 shows fragment 1 before Floor 2 loads.
- Dying after 3+ cleared rooms shows the next fragment before the run summary.
- Beating the Keeper shows a fragment, then the partial or true ending.
- Main menu shows "MEMORIES n/10" and the archive lists recovered text.
- Progress survives a restart; old saves load with 0 fragments.
