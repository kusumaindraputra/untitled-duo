## combat_hud_special_meter_test.gd — CombatHUD Special meter bar (design/gdd/special-attack.md).
##
## Coverage:
##   - special_meter_changed fills the bar and keeps the charging label below max
##   - A full meter swaps the label to the ready prompt
##   - The bar shows in combat and hides in preparation
##
## Harness: same as combat_hud_test — CombatHUDScript.new() + add_child(), process off.
## Teardown: remove_child() + free() (not queue_free — headless exit 101).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const CombatHUDScript = preload("res://src/ui/combat_hud.gd")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")


func _make_hud() -> Node:
	var hud: Node = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)
	return hud


func _teardown_hud(hud: Node) -> void:
	remove_child(hud)
	hud.free()


func test_meter_change_fills_bar_with_charging_label() -> void:
	var hud := _make_hud()
	hud._on_special_meter_changed(40.0, 100.0)
	assert_float(hud._special_bar.value).is_equal(40.0)
	assert_str(hud._special_label.text).is_equal(COPY.special_label)
	_teardown_hud(hud)


func test_full_meter_shows_ready_prompt() -> void:
	var hud := _make_hud()
	hud._on_special_meter_changed(100.0, 100.0)
	assert_str(hud._special_label.text).is_equal(InputPrompts.special_ready())
	_teardown_hud(hud)


func test_bar_visible_in_combat_hidden_in_preparation() -> void:
	var hud := _make_hud()
	hud._on_combat_started(false)
	assert_bool(hud._special_bar.visible).is_true()
	hud._on_preparation_started(0, 0)
	assert_bool(hud._special_bar.visible).is_false()
	_teardown_hud(hud)
