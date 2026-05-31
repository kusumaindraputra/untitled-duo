# Story 006: Death Animation Timing (Advisory)

> **Epic**: Enemy Instance
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: ~1.5h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-ai.md`
**Requirement**: `TR-EAI-009` (animation timing specs)

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: `AnimationPlayer.animation_finished` signal drives `queue_free()`. Story 004 wires this; this story verifies the animation asset durations match GDD specs.

**ADR: N/A for animation content** — animation duration values are art-pipeline configuration, not governed by a code architecture ADR. The `BASE_DEATH_DURATION` constant (0.7s) is defined in enemy-ai.md.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AnimationPlayer.get_animation(name).length` property stable.

**Control Manifest Rules (Core layer)**:
- Guardrail: All Visual/Feel stories require evidence doc in `production/qa/evidence/` + lead sign-off.

---

## Acceptance Criteria

*All ADVISORY — gate is ADVISORY, not BLOCKING for `/story-done`*

- [ ] **AC-EAI-21** [ADVISORY] — GIVEN `BASE_DEATH_DURATION = 0.7s`, WHEN Cluster `"death"` animation runs, THEN `$AnimationPlayer.get_animation("death").length` equals `0.53s` (±0.03s). *(Cluster dies fastest — small sprite, 4 HP.)*
- [ ] **AC-EAI-22** [ADVISORY] — GIVEN `BASE_DEATH_DURATION = 0.7s`, WHEN Drifter `"death"` animation, THEN length equals `0.70s` (±0.02s). *(Base duration.)*
- [ ] **AC-EAI-23** [ADVISORY] — GIVEN `BASE_DEATH_DURATION = 0.7s`, WHEN Charger `"death"` animation, THEN length equals `1.05s` (±0.03s). *(1.5× base — Charger is the tankiest FP enemy.)*

---

## Implementation Notes

This story is implemented by the **artist/animator**, not the programmer. The programmer's work (Stories 001–005) is complete. This story tracks that the animation assets are created and their durations match the GDD spec.

**Timing spec (from GDD):**
- Cluster (4 HP, small sprite): `0.53s = BASE_DEATH_DURATION × 0.76` — fast crumple, quick dissolve
- Drifter (20 HP): `0.70s = BASE_DEATH_DURATION × 1.0` — standard timing
- Charger (35 HP, large sprite): `1.05s = BASE_DEATH_DURATION × 1.5` — dramatic collapse

**Animation phase breakdown** (placeholder until art direction is finalized — see GDD Open Question #3):
- Frame 1 (0–30% of duration): Crumple — sprite squashes downward
- Frame 2 (30–70%): Bloom — particle burst at Prana type's jewel color
- Frame 3 (70–100%): Dissolve — sprite fades with upward float

**Note**: Art direction for the crumple→bloom→dissolve sequence must be authored before animation production begins. See `design/gdd/enemy-ai.md` Open Question #3. This story is BLOCKED on art assets — it is ADVISORY and does not block `/story-done` for the epic.

**Verification approach:**
1. Open Godot editor with EnemyInstance scene loaded
2. Select AnimationPlayer; verify three animations exist: "idle", "hit_flash", "death"
3. Check `death` animation length matches spec per archetype scene
4. Screenshot AnimationPlayer timeline for evidence doc

---

## Out of Scope

- Stories 001–005: Code implementation (all done before this story)
- Art bible review: AD gate for sprite visual style (separate from timing)

---

## QA Test Cases

*Visual/Feel story — manual verification steps.*

**AC-EAI-21 — Cluster death animation duration**
- Setup: Open `src/enemies/EnemyCluster.tscn` in Godot editor; select `AnimationPlayer`
- Verify: `death` animation exists; timeline shows length ~0.53s
- Pass condition: `|animation.length - 0.53| <= 0.03` (inspector or unit test reading `.length`)

**AC-EAI-22 — Drifter death animation duration**
- Setup: Open `src/enemies/EnemyDrifter.tscn`; select `AnimationPlayer`
- Verify: `death` animation length ~0.70s
- Pass condition: `|animation.length - 0.70| <= 0.02`

**AC-EAI-23 — Charger death animation duration**
- Setup: Open `src/enemies/EnemyCharger.tscn`; select `AnimationPlayer`
- Verify: `death` animation length ~1.05s
- Pass condition: `|animation.length - 1.05| <= 0.03`

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/death-animation-timing-evidence.md` — AnimationPlayer screenshots + duration measurements (ADVISORY — does not block epic DoD)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (AnimationPlayer.animation_finished wired); art assets must exist
- Unlocks: Nothing — advisory story; epic is functionally complete after Story 005
