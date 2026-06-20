# Difficulty Rebalance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make combat genuinely threatening by buffing enemy HP/damage and adding 0.5× elemental resistance for non-matching Prana.

**Architecture:** Two independent changes — (1) data-only stat edits in four `.tres` files, (2) a single Step 9 branch extension in `spell_casting_effects.gd`. No new files, no new systems, no schema changes.

**Tech Stack:** GDScript, GdUnit4 v6.1.3, Godot 4.6 headless test runner

---

## File Map

| File | Change |
|------|--------|
| `assets/data/enemy_types/enemy_drifter.tres` | `base_hp` 20→50, `base_damage` 8→14 |
| `assets/data/enemy_types/enemy_charger.tres` | `base_hp` 35→90, `base_damage` 20→30 |
| `assets/data/enemy_types/enemy_cluster.tres` | `base_hp` 12→30, `base_damage` 4→10 |
| `assets/data/enemy_types/enemy_rifter.tres` | `base_hp` 8→32, `base_damage` 7→12 |
| `src/systems/spell_casting_effects.gd` | Step 9: add `else: raw *= 0.5` branch |
| `tests/unit/spell-casting-effects/elemental_resistance_test.gd` | New — 2 unit tests |

---

## Task 1: Write Failing Tests for Elemental Resistance

**Files:**
- Create: `tests/unit/spell-casting-effects/elemental_resistance_test.gd`

- [ ] **Step 1: Create the test file**

```gdscript
## elemental_resistance_test.gd — Unit tests for elemental resistance (0.5×)
## added to Step 9 of spell_casting_effects.gd.
##
## Coverage:
##   AC-RESIST-01: Non-matching Prana vs affiliated enemy → raw × 0.5
##   AC-RESIST-02: Any Prana vs NONE-affiliated enemy → raw × 1.0 (no resistance)
##
## Framework: GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")


class MockHealthAndDamage:
	var call_count: int = 0
	var last_raw_damage: float = 0.0

	func apply_damage(_target: Node, raw_damage: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		call_count += 1
		last_raw_damage = raw_damage

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


class MockStatusEffectsPassthrough:
	func apply_status(_target: Node, _status_type: GameEnums.BaseStatus, _duration: float, _spell_base_damage: float = 0.0) -> void:
		pass

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage

	func has_status(_target: Node, _status_type: GameEnums.BaseStatus) -> bool:
		return false


class MockEnemy extends Node2D:
	var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
	var status_freeze_timer: float = 0.0
	var status_stun_timer: float = 0.0
	var status_burned: bool = false
	var status_blinded_timer: float = 0.0
	var status_stagger_timer: float = 0.0

	func is_alive() -> bool: return true
	func apply_speed_modifier(_mult: float) -> void: pass
	func apply_stun(_duration: float) -> void: pass


func _make_sce(mock_hd: MockHealthAndDamage = null) -> Node:
	var sce: Node = SCEScript.new()
	sce._health_and_damage = mock_hd if mock_hd != null else MockHealthAndDamage.new()
	sce._status_effects = MockStatusEffectsPassthrough.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	sce._rng = rng
	add_child(sce)
	sce.set_process(false)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


func _make_spell_effect(pt: int, tier: int, bdm: float) -> SpellEffect:
	var se: SpellEffect = SpellEffect.new()
	se.primary_type = pt
	se.primary_tier = tier
	se.base_damage_modifier = bdm
	se.combo_attack_count = tier
	se.aggregate_stat_bonus = {}
	return se


func _ready_sce(sce: Node, se: SpellEffect, target: MockEnemy) -> void:
	sce._on_combat_started(false)
	sce._on_combo_resolved(se)
	sce._override_target = target


# ── AC-RESIST-01: Non-matching Prana vs affiliated enemy → 0.5× ──────────────

## GIVEN Ashfire T1 SpellEffect (bdm=1.25); enemy affiliation = SHADOW (no match)
## WHEN _fire_attack(0) called
## THEN apply_damage called with raw ≈ 25.0 × 0.5 = 12.5
func test_sce_non_matching_prana_vs_affiliated_enemy_halves_damage() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1 (FIRE = 0)
	var enemy := MockEnemy.new()
	enemy.prana_affiliation = GameEnums.DamageClass.SHADOW  # Not FIRE — resistance applies
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# raw = 20 × 1.25 × 1.00 = 25.0; after 0.5× resistance: 12.5
	assert_float(hd.last_raw_damage).is_equal_approx(12.5, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-RESIST-02: Any Prana vs NONE-affiliated enemy → 1.0× (no resistance) ──

## GIVEN Ashfire T1 SpellEffect (bdm=1.25); enemy affiliation = NONE (no element)
## WHEN _fire_attack(0) called
## THEN apply_damage called with raw ≈ 25.0 (× 1.0 — NONE-affiliated enemies ignore resistance)
func test_sce_any_prana_vs_none_affiliated_enemy_no_resistance() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1
	var enemy := MockEnemy.new()
	# prana_affiliation stays at NONE (default) — no affiliation, no resistance
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# raw = 20 × 1.25 × 1.00 = 25.0 — no resistance multiplier for NONE-affiliated
	assert_float(hd.last_raw_damage).is_equal_approx(25.0, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)
```

- [ ] **Step 2: Run tests to verify they FAIL**

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/spell-casting-effects/elemental_resistance_test.gd --ignoreHeadlessMode
```

Expected: AC-RESIST-01 FAILS (raw_damage is 25.0 instead of 12.5). AC-RESIST-02 PASSES (already works — confirm this passes before implementing).

---

## Task 2: Implement Elemental Resistance in spell_casting_effects.gd

**Files:**
- Modify: `src/systems/spell_casting_effects.gd` (Step 9 block, around line 444)

- [ ] **Step 3: Apply the Step 9 change**

Find this block in `src/systems/spell_casting_effects.gd`:

```gdscript
	var raw_affiliation: Variant = target.get(&"prana_affiliation")
	var enemy_affiliation: int = raw_affiliation if raw_affiliation != null else GameEnums.DamageClass.NONE
	if pt != GameEnums.DamageClass.NONE and enemy_affiliation == pt:
		raw *= 2.0
		affiliation_bonus_hit.emit(target, pt)
```

Replace with:

```gdscript
	var raw_affiliation: Variant = target.get(&"prana_affiliation")
	var enemy_affiliation: int = raw_affiliation if raw_affiliation != null else GameEnums.DamageClass.NONE
	if pt != GameEnums.DamageClass.NONE and enemy_affiliation != GameEnums.DamageClass.NONE:
		if enemy_affiliation == pt:
			raw *= 2.0
			affiliation_bonus_hit.emit(target, pt)
		else:
			raw *= 0.5
```

**Why `enemy_affiliation != NONE` guard:** NONE-affiliated enemies (e.g. future bosses) have no elemental identity — neither matching nor resistant. Without this guard, any Prana cast against a NONE enemy would trigger the `else` branch and halve damage unintentionally. NONE = -1 in `DamageClass`, so this comparison is cheap.

- [ ] **Step 4: Run the new tests to verify they PASS**

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/spell-casting-effects/elemental_resistance_test.gd --ignoreHeadlessMode
```

Expected: both AC-RESIST-01 and AC-RESIST-02 PASS.

- [ ] **Step 5: Run the full spell-casting suite for regressions**

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/spell-casting-effects --ignoreHeadlessMode
```

Expected: all tests PASS. Pay special attention to:
- `damage_formula_test.gd::test_sce_ashfire_t1_neutral_damage_is_25` (AC-SC-12) — uses NONE-affiliated enemy, must still return 25.0
- `damage_formula_test.gd::test_sce_ashfire_t1_vs_fire_affiliated_enemy_doubles_damage_to_50` (AC-SC-15) — must still return 50.0

- [ ] **Step 6: Commit**

```bash
rtk git add src/systems/spell_casting_effects.gd tests/unit/spell-casting-effects/elemental_resistance_test.gd
rtk git commit -m "feat(gameplay): elemental resistance — non-matching Prana deals 0.5× vs affiliated enemies

Step 9 now branches: match → 2.0×, non-match vs affiliated → 0.5×,
NONE-affiliated enemy → 1.0× (unchanged). Preparation Phase now has
real consequences — wrong Prana = 4–6 hits while enemy counterattacks.

Story: difficulty-rebalance spec 2026-06-20"
```

---

## Task 3: Buff Enemy Stats in .tres Files

**Files:**
- Modify: `assets/data/enemy_types/enemy_drifter.tres`
- Modify: `assets/data/enemy_types/enemy_charger.tres`
- Modify: `assets/data/enemy_types/enemy_cluster.tres`
- Modify: `assets/data/enemy_types/enemy_rifter.tres`

- [ ] **Step 7: Edit enemy_drifter.tres**

Change `base_hp = 20` → `base_hp = 50` and `base_damage = 8.0` → `base_damage = 14.0`.

Final values in file:
```
base_hp = 50
base_damage = 14.0
```

- [ ] **Step 8: Edit enemy_charger.tres**

Change `base_hp = 35` → `base_hp = 90` and `base_damage = 20.0` → `base_damage = 30.0`.

Final values in file:
```
base_hp = 90
base_damage = 30.0
```

- [ ] **Step 9: Edit enemy_cluster.tres**

Change `base_hp = 12` → `base_hp = 30` and `base_damage = 4.0` → `base_damage = 10.0`.

Final values in file:
```
base_hp = 30
base_damage = 10.0
```

- [ ] **Step 10: Edit enemy_rifter.tres**

Change `base_hp = 8` → `base_hp = 32` and `base_damage = 7.0` → `base_damage = 12.0`.

Final values in file:
```
base_hp = 32
base_damage = 12.0
```

- [ ] **Step 11: Run full test suite to confirm no regressions from data changes**

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/enemy-data --ignoreHeadlessMode
```

Expected: all enemy-data tests PASS (schema tests validate structure, not specific HP values).

- [ ] **Step 12: Commit**

```bash
rtk git add assets/data/enemy_types/enemy_drifter.tres assets/data/enemy_types/enemy_charger.tres assets/data/enemy_types/enemy_cluster.tres assets/data/enemy_types/enemy_rifter.tres
rtk git commit -m "balance(enemies): buff HP 2.5–4× and damage 1.5–2× across all enemy types

Drifter: HP 20→50, dmg 8→14
Charger: HP 35→90, dmg 20→30
Cluster: HP 12→30, dmg 4→10
Rifter: HP 8→32, dmg 7→12

Paired with elemental resistance change: correct Prana = 1–2 hits,
wrong Prana = 4–6 hits while taking real damage.

Story: difficulty-rebalance spec 2026-06-20"
```

---

## Task 4: Final Verification

- [ ] **Step 13: Run the complete test suite**

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Expected: all tests PASS. Zero regressions.

- [ ] **Step 14: Manual balance smoke test**

Launch the game and run Floor 1 with a Drifter wave:
1. Arrange grid with **matching Prana** (Ashfire vs Drifter/SHADOW-affiliated... wait — check enemy affiliation in combat HUD)
2. Verify Drifter survives first hit and dies on 1–2 hits with correct Prana
3. Arrange grid with **non-matching Prana**
4. Verify Drifter takes 4–6 hits to kill and attacks Fayde during that window
5. Confirm Floor 1 is still winnable with correct Prana selection

> Note on Drifter affiliation: `prana_affiliation = 1` = `DamageClass.SHADOW` = Voidblue.
> Use Voidblue (pt=1) for the match test, any other element for the resistance test.
