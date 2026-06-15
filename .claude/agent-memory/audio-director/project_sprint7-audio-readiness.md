---
name: project-sprint7-audio-readiness
description: Audio system Sprint 7 readiness audit findings — implementation gate status, wiring gaps, and design gaps
metadata:
  type: project
---

Audit performed 2026-06-16. AudioSystem is entirely absent from project.godot Autoloads (C-001 from godot-specialist). All audio calls in PlayerController and SpellCastingEffects are currently no-ops.

**Why:** AudioSystem has been deferred for 3+ sprints. Sprint 7 is the proposed implementation window. Audit determined whether implementation can start from ADR-0012 alone.

**Verdict: READY TO IMPLEMENT — ADR-0012 is complete and sufficient for the Foundation story.** Story can start immediately from ADR-0012 + GDD. The blocker is purely absence from project.godot AutoLoads.

Key findings for future reference:

1. PlayerController footstep shuffle-bag is correctly implemented (3-variant, anti-consecutive-repeat swap). No dedicated footstep player — footsteps use the SFX pool (open question #3 in GDD not resolved). Low priority but noted.

2. SpellCastingEffects has ZERO audio event emissions. `_trigger_cast()`, `_fire_attack()`, `cast_started` signal — all silent. SC&E audio hookup is a separate story after AudioSystem foundation lands.

3. PranaGrid has ZERO audio event emissions. No confirm, place, clear, or error sounds wired.

4. Design gaps still open (not blockers for Foundation story, but block Feature story):
   - 6 GDD Open Questions remain (Boss music, Memo Resonance audio layer, CRITICAL stinger tier, AMB bus stinger ducking, slider perceptual curve, stinger restore user override) — all flagged as Vertical Slice defers.
   - Volume/accessibility settings UX not specced (Pause Menu / Settings GDD not authored).
   - Spatial audio: confirmed non-positional at MVP — no gap here.
   - 5 MVP music cues not yet composed or delivered.
   - AudioEventRegistry.tres does not exist yet — framework story creates the empty file; content is audio-director's domain.

**How to apply:** When estimating Sprint 7 audio stories, the Foundation story (AudioSystem Autoload, bus layout, pool, music FSM skeleton) can start immediately. Feature stories (SFX hookups per system) are sequenced after Foundation is verified passing. Do not block Foundation on unresolved Open Questions — all 6 are deferred to VS scope.
