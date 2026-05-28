---
name: project-audio-system-reviews
description: Review history, blocker findings, and open issues across design-review passes for the Audio System GDD
metadata:
  type: project
---

Audio System GDD (`design/gdd/audio-system.md`) has undergone four design-review passes as of 2026-05-26.

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

**Review 3 (2026-05-26):** Adversarial audio-direction review across 10 mandated challenge areas. Round 2 blockers were confirmed resolved (AMB ceiling added, DYING duck documented, dip acknowledged globally, slider debounce added). New blockers found:
1. BLOCKING — No minimum loudness floor for Prana SFX. "Magic screams" has no enforcement on the loud side — asset at −12 dBTP passes validation but fails the identity contract. Fix: add minimum true peak floor (e.g., −6 dBTP) for Prana cast / hit SFX in Visual/Audio Requirements.
2. BLOCKING — TO_END crossfade midpoint dip mitigation is physically impossible. "Strong entry attack covers the dip" fails because the incoming cue is at −80 dB when the attack occurs. DYING→END_DEFEAT path is mischaracterized (no dip — outgoing already silent). Fix: either use constant-power curve for TO_END, or sequential fade for Victory/Defeat. Clarify DYING→END_DEFEAT path separately.
3. BLOCKING — AMB bus not ducked during stinger. At memory_final duck (−14 dB), Music drops to −20 dB while AMB stays at −12 dB. AMB becomes louder than Music at the plot twist moment. Fix: add AMB duck path for NARRATIVE stingers in Core Rule 12.
4. BLOCKING — 0.1s DYING fade is in click-artifact zone (not a perceptible fade, not a clean cut). Tuning Knob note says "too short: abrupt mute" but the default is 0.1s, which IS an abrupt mute. Fix: either set 0.0s (instant cut, use the fade_duration guard) or set 0.05s and document as de-click fade, not a perceptible transition.
5. BLOCKING — COMBAT→END_DEFEAT 2.0s simultaneous crossfade produces a 2-second audio clash (high-energy combat music blends with defeat theme at equal volume at midpoint). No composer guidance for this specific pair. Fix: either route all END_DEFEAT through DYING silence, or reduce TO_END duration for direct COMBAT→END_DEFEAT path, or add explicit composer guidance.
6. BLOCKING — NARRATIVE stinger priority blocks boss spawn stinger with no CRITICAL escape hatch. A memory fragment stinger playing when a boss spawns silently discards the boss spawn audio cue. Fix: add stinger_priority = 2 (CRITICAL) tier that preempts all stingers including NARRATIVE, and assign boss_spawn to CRITICAL.
7. BLOCKING — Linear dB slider dead zone is a launch-visible player-facing defect. Bottom 25% of slider produces no audible change; players will report broken audio. Fix is 1–3 lines of code (square-root or logarithmic curve). Must not ship as post-MVP deferral.
8. BLOCKING — User volume change during active stinger duck is overwritten by restore. Player adjusts Music volume during a 2s stinger; on stinger finish, restore resets to pre-duck value, discarding the user's manual change. Fix: check whether user-modified volume differs from stored pre-duck value before restoring; if changed, skip restore.
9. BLOCKING — Music player node volume_db has no enforced upper bound. Bus ceiling at −3 dB does not prevent player node from being set to +6 dB (Godot allows positive volume_db on AudioStreamPlayer). Fix: GDD must explicitly require music player nodes target volume_db = 0.0 as maximum.

Advisory findings (Round 3):
10. RECOMMENDED — −3 dB Music-to-SFX headroom claim is scoped wrong. "Architecturally enforces at least 3 dB headroom" is false when user reduces SFX volume below default. Scope the claim to "within default bus configuration."
11. RECOMMENDED — boss_kill stinger call site is unconfirmed and its interaction with a competing NARRATIVE stinger is undocumented. Note for Boss Encounter GDD #11.

**How to apply:** All 9 Round-3 blockers must be resolved before GDD advances. Advisories 10–11 are documentation accuracy and content gaps.
