# Story 004: Chain Dots

> **Epic**: CombatHUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: ~1 hour
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-10

## Context

**GDD**: `design/gdd/combat-hud.md`
**Requirement**: `TR-CH-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: Chain dot state is driven exclusively by `SpellCastingEffects.chain_index_changed(combo_index, combo_attack_count)`. CombatHUD uses `PranaCatalog.get_type(primary_type_id).color` for active dot colour — no hardcoded hex for Prana colours (TR-CH-004). Fallback to white if spell effect is null.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Dot nodes are programmatically created `ColorRect` or `Panel` nodes inside `ChainDotsContainer (HBoxContainer)`. `PranaCatalog.get_type(id).color` returns a `Color` directly.

**Control Manifest Rules (Presentation Layer)**:
- Required: Chain dot colors from `PranaCatalog.get_type(id).color` — NOT hardcoded hex (TR-CH-004)
- Required: Signal consumer only — never read SC&E state directly

---

## Acceptance Criteria

*From GDD `design/gdd/combat-hud.md`, scoped to this story:*

- [ ] **AC-HUD-10** — GIVEN SC&E has cached SpellEffect with `primary_type == 2` (Stormgold); `preparation_started` received; `combat_started` fires; `chain_index_changed(0, 2)` fires; WHEN processed; THEN chain dots node is visible; 2 dots drawn; dot[0] color == Stormgold (`Color("#FFCC00")`); dot[1] color == `Color("#888888")`
- [ ] **AC-HUD-11** — GIVEN chain dots visible (combo_attack_count=2, primary_type=0 Ashfire); `chain_index_changed(1, 2)` fires; WHEN processed; THEN dot[1] color == Ashfire (`Color("#F24C1D")`); dot[0] == `Color("#888888")`
- [ ] **AC-HUD-12** — GIVEN chain dots visible during COMBAT; `preparation_started` fires; WHEN processed; THEN chain dots node is NOT visible
- [ ] **AC-HUD-26** [M] — GIVEN a damage label spawns at enemy position; WHEN 0.8s elapses; THEN label position has risen ~32px from spawn Y AND label alpha ≈ 0.0 AND label is freed. *(Manual — visual scene required. Relates to Story 003 animation; verified here as part of visual QA sweep.)*

---

## Implementation Notes

*Derived from GDD Rule 5 and Formula 3:*

**Chain dot container** — `ChainDotsContainer` is an `HBoxContainer` in CombatHUD scene. Hidden by default; shown on `chain_index_changed`.

**`_on_chain_index_changed(combo_index: int, combo_attack_count: int)`**:
```gdscript
func _on_chain_index_changed(combo_index: int, combo_attack_count: int) -> void:
    chain_dots_container.visible = true
    _rebuild_dots(combo_index, combo_attack_count)

func _rebuild_dots(active_index: int, count: int) -> void:
    # Clear existing dots
    for child in chain_dots_container.get_children():
        child.queue_free()
    # Determine active Prana color
    var active_color: Color = Color("#FFFFFF")  # fallback per Edge Case
    var pt: int = _current_primary_type  # cached from last chain_index_changed
    if pt >= 0 and pt <= 4:
        active_color = PranaCatalog.get_type(pt).color
    # Spawn N dots
    for i: int in range(count):
        var dot := ColorRect.new()
        dot.custom_minimum_size = Vector2(6.0, 6.0)
        dot.color = active_color if i == active_index else Color("#888888")
        chain_dots_container.add_child(dot)
```

**Tracking primary type** — SC&E emits `chain_index_changed(combo_index, combo_attack_count)` but does NOT emit the primary_type. CombatHUD needs `_current_primary_type` which it acquires by connecting to `SpellCastingEffects.spell_hit_element(target, prana_type_id)` (already connected in Story 003) — the first hit tells CombatHUD the primary type. Alternative: connect to `CombinationResolution.combo_resolved` to read `spell_effect.primary_type` directly. The GDD Rule 5 says: "Active dot color = `PranaCatalog.get_type(primary_type_id).color`". Use `SpellCastingEffects.get_stat_bonus()` to query — no, that's for stat bonuses. The cleanest FP approach: when `combo_resolved` fires, cache `spell_effect.primary_type` on CombatHUD:

```gdscript
# In _ready():
CombinationResolution.combo_resolved.connect(_on_combo_resolved)

func _on_combo_resolved(spell_effect: SpellEffect) -> void:
    _current_primary_type = spell_effect.primary_type
```

This matches the GDD Rule 5 ("dot color = PranaCatalog.get_type(primary_type_id)") and avoids polling.

**Hide on preparation_started** (AC-HUD-12):
```gdscript
func _on_preparation_started(_idx: int, _rem: int) -> void:
    chain_dots_container.visible = false
    _current_primary_type = -1
```

**Prana color reference** (for test assertions):
- Ashfire (0): `Color("#F24C1D")` — verify exact value from PranaCatalog prana_fire.tres
- Stormgold (2): `Color("#FFCC00")` — verify exact value from prana_lightning.tres

Test: read actual color from `PranaCatalog.get_type(0).color` at test time rather than hardcoding in the assertion — this avoids test brittleness if colors are tuned.

---

## Out of Scope

- [Story 001]: HP bar skeleton, signal connections skeleton
- [Story 002]: Zone colours
- [Story 003]: Damage number labels (float animation tested there; AC-HUD-26 is a manual sweep here)

---

## QA Test Cases

*Embedded from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-09 chain dots specs).*

**Test file**: `tests/unit/combat-hud/combat_hud_test.gd` (chain dots section)
**Evidence file**: `production/qa/evidence/combat-hud-chain-evidence.md`

- **AC-HUD-10**: Chain dots appear with correct Prana color on chain_index_changed
  - Given: CombatHUD in tree; `CombinationResolution.combo_resolved.emit(stormgold_t2_effect)` fired (primary_type=2)
  - When: `SpellCastingEffects.chain_index_changed.emit(0, 2)`
  - Then: `chain_dots_container.visible == true`; 2 dot children exist; dot[0].color == `PranaCatalog.get_type(2).color`; dot[1].color == `Color("#888888")`

- **AC-HUD-11**: Second chain_index_changed advances active dot
  - Given: dots visible (combo_attack_count=2, primary_type=0 Ashfire); first dot[0] was active
  - When: `SpellCastingEffects.chain_index_changed.emit(1, 2)`
  - Then: dot[1].color == `PranaCatalog.get_type(0).color` (Ashfire); dot[0].color == `Color("#888888")`

- **AC-HUD-12**: preparation_started hides chain dots
  - Given: chain_dots_container.visible == true
  - When: `GameStateManager.preparation_started.emit(0, 1)`
  - Then: `chain_dots_container.visible == false`

**Manual [M] AC-HUD-26**: Damage label float and fade animation
  - Setup: Run game in Godot editor; trigger a spell hit so `damage_taken` fires for an enemy
  - Verify: spawned label rises ~32px and fades to transparent over ~0.8s, then disappears
  - Pass: label is no longer in scene tree after 0.8–1.0s; visual ascent and fade observable

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/combat-hud-chain-evidence.md` + sign-off (ADVISORY)
Unit tests in `tests/unit/combat-hud/combat_hud_test.gd` strongly recommended.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (skeleton, signal connections); Story 003 DONE (damage labels connected, `_current_primary_type` infrastructure)
- Unlocks: None — this is the final CombatHUD story. Epic complete when this story is Done.

---

## Completion Notes
**Completed**: 2026-06-10
**Criteria**: 3/4 passing (AC-HUD-26 DEFERRED — manual visual test, requires game session)
**Deviations**: ADVISORY — `Color("#888888")` hardcoded for inactive dots; TR-CH-004 only forbids hardcoding Prana-type colors, which are correctly sourced from PranaCatalog.
**Test Evidence**: Visual/Feel — evidence file not yet created (ADVISORY). Unit tests: `tests/unit/combat-hud/combat_hud_test.gd` (26/26 passing, 3 new chain-dot tests added).
**Code Review**: Complete (lean mode, confirmed by developer)
