# Story 005: Prana Type Visual Differentiation

> **Epic**: Spell Casting & Effects
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: 2.5 days
> **Sprint ID**: S5-03
> **Manifest Version**: 2026-06-12
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/spell-casting-effects.md`
**Supporting GDD**: `design/gdd/prana-data.md` (CastAnimation enum, VfxBurstShape enum)
**Sprint**: Sprint 5 — Legibility Pass

**Playtest finding (Sprint 4)**: Tester SAK could not visually distinguish which Prana type just fired. All spells looked identical. This is the #1 legibility failure identified in the PARTIALLY CONFIRMED fun hypothesis verdict.

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
SC&E already emits `spell_hit_element(target, prana_type_id)` on each valid hit. The VFX system subscribes to this signal — no polling of SC&E state.

**Engine**: Godot 4.6 | **Risk**: MEDIUM — GPUParticles2D API differs from Godot 3; verify particle lifetime and emission shape API against docs/engine-reference/godot/ before implementation.

---

## ⚠️ Pre-Implementation Requirement (GAP-1)

`design/gdd/spell-casting-effects.md` Visual/Audio Requirements section reads `[To be designed]`.

**Before implementing this story**, author a Quick Spec (or inline amendment) answering:
1. Which node owns VFX emission? **Recommendation**: a `SpellVFX` autoload (or SC&E child node) that subscribes to `spell_hit_element` and spawns per-hit particle scenes
2. VFX emission point: `target.global_position` for hit bursts; Fayde's `global_position` for cast animation overlay
3. Particle color source: `PranaCatalog.get_type(prana_type_id).color` — never hardcoded
4. FP scope constraint: all VFX are code-driven `GPUParticles2D` — **no texture or sprite asset dependency**
5. CastAnimation routing: plays a `string_name` variant on an `AnimationPlayer` node on Fayde (e.g., `"cast_thrust"`, `"cast_reach"`) OR uses a separate Fayde animation overlay — confirm approach before implementation

Once the Quick Spec is written, back-fill this section and mark GAP-1 RESOLVED.

---

## Acceptance Criteria

*Derived from playtest findings + prana-data.md enum spec.*

- [ ] **AC-VD-01** — Each of the 5 Prana types produces a visually distinct hit burst: Ashfire = orange/red flame cluster, Voidblue = inward blue spiral, Stormgold = forked gold lightning, Deepfrost = cyan hexagonal crystal, Verdant = green vine/leaf expansion
- [ ] **AC-VD-02** — `spell_hit_element(target, prana_type_id)` signal emitted for each type (0–4) on a valid hit; prana_type_id matches the primary type of the current SpellEffect
- [ ] **AC-VD-03** — VFX burst uses `PranaCatalog.get_type(prana_type_id).color` as particle color — no hardcoded hex
- [ ] **AC-VD-04** — `VfxBurstShape` enum correctly routes per type: BURST_FLAME(0), BURST_SPIRAL(1), BURST_LIGHTNING(2), BURST_CRYSTAL(3), BURST_VINE(4)
- [ ] **AC-VD-05** — Cast animation routes per type: CAST_THRUST(0), CAST_REACH(1), CAST_SNAP(2), CAST_PUSH(3), CAST_BLOOM(4)
- [ ] **AC-VD-06** — On miss (no target): cast VFX fires in facing direction; `spell_hit_element` NOT emitted
- [ ] **AC-VD-07** — `tier_attack_modifier == 0.0` attacks (Verdant T2, Deepfrost T3 glacial field): VFX fires; `apply_damage` NOT called
- [ ] **AC-VD-08** — `primary_type == -1` (no-op SpellEffect): no VFX, no `spell_hit_element` signal
- [ ] **AC-VD-09** [M] — **Discoverability test**: a non-developer observer correctly names ≥3/5 Prana types by visual alone within 5 minutes of directed play

---

## Out of Scope

- Audio: `play_event(&"sfx_cast_[type_name]")` already stubbed in SC&E — Audio System is VS scope
- Status effect VFX (Burn contagion arc, Shatter crack effect) — MVP scope per prana-data.md Discovery Signal Contract
- Size scaling of burst by damage magnitude — MVP scope
- Animated cast sprites (sprite sheets) — no art assets at FP; code-driven particles only

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-5-2026-06-12.md` (S5-03 specs).*

**Test file**: `tests/unit/spell-casting-effects/sce_visual_routing_test.gd`
**Evidence file**: `production/qa/evidence/sprint-5-prana-visuals-evidence.md`

> ⚠️ VFX node path assertions are placeholders — fill in after GAP-1 Quick Spec is authored.

- **AC-VD-02/04**: `spell_hit_element` emits correct prana_type_id for each type (0–4)
  - Given: SC&E in READY state with SpellEffect for each primary_type 0–4 (5 separate test cases)
  - When: cast fires on valid target for each type
  - Then: `spell_hit_element.emit(target, N)` called with prana_type_id == N for each case

- **AC-VD-04**: VfxBurstShape routing from PranaCatalog
  - Given: `PranaCatalog` loaded
  - Then: `PranaCatalog.get_type(0).vfx_burst_shape == GameEnums.VfxBurstShape.BURST_FLAME`
  - Then: `PranaCatalog.get_type(1).vfx_burst_shape == GameEnums.VfxBurstShape.BURST_SPIRAL`
  - Then: `PranaCatalog.get_type(2).vfx_burst_shape == GameEnums.VfxBurstShape.BURST_LIGHTNING`
  - Then: `PranaCatalog.get_type(3).vfx_burst_shape == GameEnums.VfxBurstShape.BURST_CRYSTAL`
  - Then: `PranaCatalog.get_type(4).vfx_burst_shape == GameEnums.VfxBurstShape.BURST_VINE`

- **AC-VD-05**: CastAnimation routing from PranaCatalog
  - Then: `PranaCatalog.get_type(0).cast_animation == GameEnums.CastAnimation.CAST_THRUST`
  - (etc. for types 1–4)

- **AC-VD-06**: Miss — `spell_hit_element` NOT emitted
  - Given: SC&E in READY with Ashfire T1 SpellEffect; `primary_target == null` (ray finds no collision)
  - When: cast fires
  - Then: `spell_hit_element` NOT emitted; `_combo_index == 1` (chain advances)

- **AC-VD-07**: Zero-modifier attack — VFX fires; apply_damage NOT called
  - Given: Verdant T2 SpellEffect; cast advances to index 1 (SELF, modifier=0.0)
  - When: cast fires
  - Then: VFX node [path TBD] received activation call; `apply_damage` NOT called

- **AC-VD-08**: No-op SpellEffect — no VFX, no signal
  - Given: `_on_combo_resolved` called with `primary_type == -1`
  - When: cast fires
  - Then: no VFX; `spell_hit_element` NOT emitted; `_state == IDLE`

**Manual [M] AC-VD-09**: Discoverability test
  - Setup: arranged session with non-developer; isolate each Prana type; cast 2–3 times each
  - Verify: observer names the element without being told
  - Pass: ≥3 correct identifications; record which types passed/failed in evidence file

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/sprint-5-prana-visuals-evidence.md` — screenshot/screen-recording per type + discoverability test result (ADVISORY gate)
**Automated test**: `tests/unit/spell-casting-effects/sce_visual_routing_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: spell-casting-effects story-001 through story-004 DONE; GAP-1 Quick Spec authored
- Unlocks: Re-validation playtest can proceed (one of 3 discoverability gates)
