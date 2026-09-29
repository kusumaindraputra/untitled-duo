---
name: project-audio-identity
description: Sonic directive, game context, and key audio design decisions for The Last Cipher
metadata:
  type: project
---

The game's audio design directive is "The world breathes softly; magic screams." Ayden and Faith, two android brothers sharing one Prana core, fight robots in a quiet underground world using elemental Prana abilities. All-ages (7+), pixel art, sci-fi dungeon crawler.

**Why:** This contrast is the core emotional contract — ambient and preparation audio are understated/textural, Prana SFX are loud and sharp. Every audio decision should be evaluated against this axis.

**How to apply:** When evaluating any sound design choice, ask: does this live on the "breathes softly" side or the "magic screams" side? AMB and Preparation cues belong on the soft side. Prana casts, enemy hits, and death sounds belong on the loud side.

Key decided parameters (current as of GDD revision 2026-05-23):
- Delivery standard: -18 LUFS integrated, -1 dBTP true peak
- Default bus levels: Master 0.0, Music -6.0, SFX 0.0, UI -3.0, AMB -12.0 dB
- Pool size: 24 slots (raised from 16; worst-case sizing: full 3×3 combo + Cluster swarm = ~20 events)
- Music bus ceiling: -3.0 dB (enforced by setter clamping)
- 5 MVP music cues: Main Menu, Preparation, Combat, Victory, Defeat (DYING = intentional silence)
- Music looping format: RESOLVED — pre-looped OGG files (LOOP_FORWARD, baked by composer)
- No 3D spatial audio at MVP (top-down 2D, all sounds non-positional)
- No voice acting at MVP

Open questions as of 2026-05-23 (post-revision):
- Footstep audio ownership — still open, resolve in Player Controller GDD
- RESOLVED: Music looping format (pre-looped OGG)
- RESOLVED: death_started signal confirmed in Game State & Scene Flow GDD

Pending GDD blockers from Re-Review (2026-05-23):
- AMB bus has no enforced ceiling — needs same architectural treatment as Music bus ceiling
- Stinger duck behavior in DYING state undocumented (duck fires into silence — must be noted as intentional)
- ~3 dB crossfade dip only acknowledged for COMBAT→PREPARATION; applies to all simultaneous linear crossfades
- Single UI player has no stated policy for continuous slider-drag input in Settings
