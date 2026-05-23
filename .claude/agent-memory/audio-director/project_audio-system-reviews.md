---
name: project-audio-system-reviews
description: Review history, blocker findings, and open issues across design-review passes for the Audio System GDD
metadata:
  type: project
---

Audio System GDD (`design/gdd/audio-system.md`) has undergone three design-review passes as of 2026-05-23.

**Review 1 (2026-05-22):** 14 blockers found. All resolved in revision pass (pool raised to 24, DYING state added, A/B ambient added, Tween API patterns locked, etc.).

**Review 2 (2026-05-23):** Post-revision adversarial re-review. Architecture-correctness blockers from Review 1 were confirmed resolved. New audio-direction blockers identified:
1. BLOCKING — AMB bus has no enforced ceiling (Music bus has −3 dB ceiling; AMB has none). "Breathes softly" half of identity directive lacks architectural enforcement. Fix: add AMB bus upper bound (~−10 dB), enforced by setter clamping.
2. BLOCKING — Stinger duck behavior in DYING state is undocumented. Duck fires into silence (Music already at −80 dB). Not a bug — intentional — but will confuse implementors. Fix: add explicit note in Core Rule 12 and DYING state spec.
3. BLOCKING — ~3 dB simultaneous linear crossfade dip is acknowledged only for COMBAT→PREPARATION. Applies to all simultaneous linear crossfades including the 2s TO_END fade. Fix: either acknowledge globally in Formula 1 or specify constant-power curves for long emotionally significant fades.
4. BLOCKING — Single UI player has no policy for continuous slider-drag input. 30+ events/sec on slider drag will produce audio stutter or silence. Fix: add debounce/rate-limit guidance to Core Rule 7 or UI Requirements.

Advisory findings (non-blocking):
5. 5-cue structure has no intra-state escalation; Combat cue guidance lacks replayability guidance.
6. Preparation cue 8–16 bar guidance contradicts "shorter loop" rationale given alongside it; recommend 4–8 bars.
7. −18 LUFS integrated is meaningless for short transient SFX. Spec needs per-category measurement guidance.
8. Prana collection has no per-type audio identity spec (5 Prana types need distinct collect variants).
9. A/B ambient supports one layer; Player Fantasy implies state-reactive ambient swaps that are unspecified as a system responsibility.

**How to apply:** All 4 blockers must be resolved before GDD status advances from "In Design." Advisories are content spec gaps affecting sound design production, not framework implementation.
