# Fast-Pace Layer — Visual Evidence (ADR-0019)

Captured 2026-09-24 with `--write-movie` under xvfb (Godot 4.6.2, Compatibility
renderer, god mode on) from a throwaway harness that boots `demo.tscn` into combat,
fires one Perfect Dodge and then kills enemies nearest-first.

| Shot | What it shows |
|------|---------------|
| `fast-pace/perfect-dodge.png` | "PERFECT DODGE" callout over Fayde, the Special meter at 12 from the dodge, the live style meter (STYLE C) under the room breadcrumb. |
| `fast-pace/room-rank.png` | Room clear: "RANK B" banner with its reward line (+4 HP, +10 Special next room); the live style meter hides; orbs flying in from the far side of the room. |
| `fast-pace/boss-hud-fixed.png` | Boss bar and "VAULT SENTINEL" name card top-centre, clear of Fayde's HP bar (compare `bullet-hell/boss-phase3.png`, where both sat on top of it). |
| `fast-pace/quick-continue.png` | Preparation with an unchanged build: the button reads "Continue ▶" and the hint says Space or Enter continues. |

Headless log from the same run: the first kills near Fayde were collected at once
(Special 12 → 21, +3 per meter orb); after the last kill the room ranked and every
remaining orb was magnetised. No script errors.
