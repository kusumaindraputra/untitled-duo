# Pixel-Art Spell VFX — Visual Evidence (ADR-0023)

Captured 2026-09-25 under xvfb (Godot 4.6.2, Compatibility renderer, 1152×648, god
mode on). The throwaway harness filled the Prana grid with five fragments of one
type, pressed `cast` eight times, and zoomed the camera to 2.2×.

| Shot | What it shows |
|------|---------------|
| `pixel-vfx/before-after-5-prana.png` | Top row: the main build before this change (antialiased vector strokes). Bottom row: after, for Ashfire, Voidblue, Stormgold, Deepfrost and Verdant (crops scaled 2× with Nearest). |
| `pixel-vfx/after-full-deepfrost.png` | Full frame of a Deepfrost cast: pixel shards, cast beam, range cone scanlines. |

The glowing balls with trails in some frames are enemy projectiles, which are out
of scope here and still drawn as vectors.
