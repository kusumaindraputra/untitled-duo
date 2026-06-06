# Story 003: Floating Damage Numbers

> **Epic**: CombatHUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: ~1.5 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: —

## Context

**GDD**: `design/gdd/combat-hud.md`
**Requirement**: `TR-CH-003`, `TR-CH-005`, `TR-CH-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: `spell_hit_element` and `damage_taken` signals are correlated within the same frame via a per-frame pending-element dictionary. `damage_taken` is the trigger for label spawn; `spell_hit_element` provides the colour if received in the same frame for the same target. CombatHUD never calls SC&E directly.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_viewport().get_canvas_transform()` for world-space → viewport conversion is the Godot 4.x API (TR-CH-003). `Label` created via `Label.new()` and parented to the CanvasLayer for world-overlaid display. `create_tween()` for float + fade animation.

**Control Manifest Rules (Presentation Layer)**:
- Required: Signal consumer only — never reads Autoload state directly
- Required: `get_viewport().get_canvas_transform()` for world-space coordinate conversion (TR-CH-003)
- Required: Pool cap of 12 labels; oldest-first eviction (TR-CH-006)

---

## Acceptance Criteria

*From GDD `design/gdd/combat-hud.md`, scoped to this story:*

- [ ] **AC-HUD-13** — GIVEN `damage_taken(enemy_node, 25, 10)` fires; WHEN processed; THEN a Label node exists as CanvasLayer child; text == "25"
- [ ] **AC-HUD-14** — GIVEN: emit `spell_hit_element(enemy_node, 2)` (Stormgold) AND `damage_taken(enemy_node, 23, 12)` before `await get_tree().process_frame`; WHEN frame processed; THEN spawned label color == `Color("#FFCC00")` (Stormgold)
- [ ] **AC-HUD-15** — GIVEN: emit `spell_hit_element(enemy_A, 2)` AND `damage_taken(enemy_B, 16, 10)` (enemy_B ≠ enemy_A) before next frame; WHEN frame processed; THEN label for enemy_B color == `Color("#FFFFFF")` (element signal for enemy_A not applied to enemy_B)
- [ ] **AC-HUD-16** — GIVEN `damage_taken(enemy_node, 16, 10)` fires; no `spell_hit_element` for this target in same frame; WHEN label spawns; THEN label color == `Color("#FFFFFF")`
- [ ] **AC-HUD-17** — GIVEN `damage_taken(fayde_node, 20, 80)` fires; WHEN label spawns; THEN label color == `Color("#AAAAAA")`; label position derived from `fayde_node.global_position`
- [ ] **AC-HUD-18** — GIVEN 12 Label nodes active as CanvasLayer children; `damage_taken` fires; WHEN new label spawns; THEN oldest label was freed BEFORE new spawn; active label count ≤ 12
- [ ] **AC-HUD-19** — GIVEN 5 Label nodes active (below cap of 12); `damage_taken` fires; WHEN new label spawns; THEN no existing label freed; CanvasLayer has 6 label children

---

## Implementation Notes

*Derived from GDD Rule 7 and TR-CH-003, TR-CH-005, TR-CH-006:*

**Per-frame element correlation (TR-CH-005)**:
```gdscript
# Store pending element hits received this frame — cleared after _process() or process_frame
var _pending_element: Dictionary = {}  # target Node → prana_type_id (int)

func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
    _pending_element[target] = prana_type_id

func _on_damage_taken(target: Node, final_damage: float, _current_hp: float) -> void:
    if _dead and target.is_in_group(&"player"): return
    if final_damage <= 0.0: return
    var color: Color
    if target.is_in_group(&"player"):
        color = Color("#AAAAAA")
    elif _pending_element.has(target):
        var pt: int = _pending_element[target]
        color = PranaCatalog.get_type(pt).color
    else:
        color = Color("#FFFFFF")
    _pending_element.erase(target)
    _spawn_damage_label(target, int(final_damage), color)
```
Clear `_pending_element` each frame (or rely on per-target erase after use — per-target erase is simpler and avoids needing a _process() flush).

**Coordinate conversion (TR-CH-003)**:
```gdscript
func _spawn_damage_label(target: Node, damage: int, color: Color) -> void:
    _evict_if_at_cap()
    var label := Label.new()
    label.text = str(damage)
    label.add_theme_color_override(&"font_color", color)
    # World-space → viewport (CanvasLayer coordinate space)
    var world_pos: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
    var vp_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
    label.position = vp_pos + Vector2(randf_range(-8.0, 8.0), 0.0)  # spawn jitter
    add_child(label)
    _animate_damage_label(label)
```
`add_child(label)` parents label to the CanvasLayer (CombatHUD's parent is the CanvasLayer — but if CombatHUD is a Control node INSIDE the CanvasLayer, use `get_parent().add_child(label)` or add to `self` and accept the Control's coordinate space).

**Float + fade animation (GDD Formula 2)**:
```gdscript
const DAMAGE_FLOAT_DISTANCE: float = 32.0
const DAMAGE_FLOAT_DURATION: float = 0.8
const DAMAGE_FADE_START: float = 0.5

func _animate_damage_label(label: Label) -> void:
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(label, "position:y", label.position.y - DAMAGE_FLOAT_DISTANCE, DAMAGE_FLOAT_DURATION)
    t.tween_interval(DAMAGE_FADE_START)
    t.chain().tween_property(label, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION - DAMAGE_FADE_START)
    t.chain().tween_callback(label.queue_free)
```

**Pool cap (TR-CH-006)** — track active labels in `_active_damage_labels: Array[Label]`:
```gdscript
const DAMAGE_LABEL_POOL_CAP: int = 12

func _evict_if_at_cap() -> void:
    _active_damage_labels = _active_damage_labels.filter(func(l): return is_instance_valid(l))
    if _active_damage_labels.size() >= DAMAGE_LABEL_POOL_CAP:
        var oldest: Label = _active_damage_labels.pop_front()
        if is_instance_valid(oldest): oldest.free()

func _free_all_damage_labels() -> void:
    for l: Label in _active_damage_labels:
        if is_instance_valid(l): l.free()
    _active_damage_labels.clear()
```
Call `_free_all_damage_labels()` in `_on_run_started()` (Story 001 placeholder was left for this).

**Test approach** — unit tests emit signals and check label child count / text / color directly:
```gdscript
HealthAndDamage.damage_taken.emit(mock_enemy, 25.0, 10.0)
# Collect labels: filter children by type
var labels = hud.get_children().filter(func(c): return c is Label)
assert_int(labels.size()).is_equal(1)
assert_str(labels[0].text).is_equal("25")
```
For same-frame correlation (AC-HUD-14): emit `spell_hit_element` then `damage_taken` without any `await` between them.

---

## Out of Scope

- [Story 001]: HP bar skeleton, damage_taken routing for Fayde (already connected — Story 003 extends the handler)
- [Story 002]: Zone colors
- [Story 004]: Chain dots

---

## QA Test Cases

*Embedded from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-09 specs).*

**Test file**: `tests/unit/combat-hud/combat_hud_test.gd` (damage labels section)

- **AC-HUD-13**: Label spawns on damage_taken > 0 with correct text
  - Given: CombatHUD in tree; MockEnemy not in "player" group
  - When: `HealthAndDamage.damage_taken.emit(mock_enemy, 25.0, 10.0)`
  - Then: a Label child exists; `label.text == "25"`

- **AC-HUD-14**: Same-frame spell_hit_element → Prana color on label
  - Given: `mock_enemy` prepared; `SpellCastingEffects.spell_hit_element.emit(mock_enemy, 2)` (Stormgold)
  - When: `HealthAndDamage.damage_taken.emit(mock_enemy, 23.0, 12.0)` (same frame, no await)
  - Then: spawned label font color == `Color("#FFCC00")` (Stormgold color from PranaCatalog)

- **AC-HUD-15**: Wrong-target element signal → white label
  - Given: `spell_hit_element.emit(enemy_A, 2)`; `damage_taken.emit(enemy_B, 16.0, 10.0)` (B ≠ A)
  - When: frame processes
  - Then: label for enemy_B color == `Color("#FFFFFF")` (not Stormgold)

- **AC-HUD-16**: No element signal → white label (neutral enemy hit)
  - Given: no `spell_hit_element` emitted this frame for mock_enemy
  - When: `damage_taken.emit(mock_enemy, 16.0, 10.0)`
  - Then: label font color == `Color("#FFFFFF")`

- **AC-HUD-17**: Fayde-received → grey label
  - Given: MockFayde in "player" group
  - When: `damage_taken.emit(mock_fayde, 20.0, 80.0)`
  - Then: label font color == `Color("#AAAAAA")`

- **AC-HUD-18**: 13th damage → evicts oldest before spawn; count ≤ 12
  - Given: 12 Label children manually added to `hud._active_damage_labels`
  - When: `damage_taken.emit(mock_enemy, 5.0, 5.0)`
  - Then: oldest was freed (count remains ≤ 12); new label text == "5"
  - Edge cases: verify oldest freed BEFORE new label added

- **AC-HUD-19**: Below-cap damage → no eviction; count increments
  - Given: 5 Labels active
  - When: `damage_taken.emit(mock_enemy, 8.0, 8.0)`
  - Then: no label freed; total active labels == 6

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat-hud/combat_hud_test.gd` — must exist and pass (BLOCKING)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (CombatHUD skeleton with signal connections; `_free_all_damage_labels` stub)
- Unlocks: Story 004 — Chain Dots
