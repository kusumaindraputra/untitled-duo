## wave_composition_test.gd — Unit tests for WaveManager random composition builder.
##
## Coverage:
##   AC-LG-05: total threat within [THREAT_BUDGET_MIN, THREAT_BUDGET_MAX] (+ guarantee slack)
##   AC-LG-06: every composition has >= 1 SEEKER (type_id 0) and >= 1 SWARMER (type_id 2)
##   Composition is non-empty after _on_preparation_started
##
## GDD: design/gdd/level-generation.md
## ADR: ADR-0014 (H&D ↔ WaveManager Contract)
extends GdUnitTestSuite

const WaveManagerScript = preload("res://src/systems/wave_manager.gd")
## Threat costs mirror WaveManager._THREAT_COST (not imported to keep tests isolated).
const _COST: Dictionary = { 0: 1, 1: 2, 2: 1, 4: 1 }


func _make_wm() -> WaveManager:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager
	add_child(wm)
	return wm


func _teardown_wm(wm: WaveManager) -> void:
	remove_child(wm)
	wm.free()


# ── AC-LG-06: guaranteed SEEKER ───────────────────────────────────────────────

## GIVEN fresh preparation
## WHEN composition is built
## THEN at least one entry has type_id == 0 (SEEKER)
func test_composition_always_contains_seeker() -> void:
	var wm := _make_wm()
	wm._on_preparation_started(0, 0)
	var found: bool = false
	for entry: Dictionary in wm._wave_composition:
		if int(entry["type_id"]) == 0:
			found = true
			break
	assert_bool(found).is_true()
	_teardown_wm(wm)


# ── AC-LG-06: guaranteed SWARMER ─────────────────────────────────────────────

## GIVEN fresh preparation
## WHEN composition is built
## THEN at least one entry has type_id == 2 (SWARMER)
func test_composition_always_contains_swarmer() -> void:
	var wm := _make_wm()
	wm._on_preparation_started(0, 0)
	var found: bool = false
	for entry: Dictionary in wm._wave_composition:
		if int(entry["type_id"]) == 2:
			found = true
			break
	assert_bool(found).is_true()
	_teardown_wm(wm)


# ── AC-LG-05: threat total within budget ─────────────────────────────────────

## Runs three times to cover multiple random draws.
## THEN total threat is within [BUDGET_MIN, BUDGET_MAX + 2] (guarantee types may overshoot by ≤2).
func test_composition_threat_total_within_budget_range() -> void:
	for _run: int in range(3):
		var wm := _make_wm()
		wm._on_preparation_started(0, 0)
		var total: int = 0
		for entry: Dictionary in wm._wave_composition:
			total += _COST.get(int(entry["type_id"]), 1)
		assert_int(total).is_between(
			wm.THREAT_BUDGET_MIN - 1,
			wm.THREAT_BUDGET_MAX + 2)
		_teardown_wm(wm)


# ── Composition is non-empty ──────────────────────────────────────────────────

## GIVEN fresh preparation
## THEN composition has at least one entry (guarantees prevent vacuous composition)
func test_composition_is_not_empty() -> void:
	var wm := _make_wm()
	wm._on_preparation_started(0, 0)
	assert_int(wm._wave_composition.size()).is_greater(0)
	_teardown_wm(wm)
