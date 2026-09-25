## sigil_effects_test.gd — Unit tests for the behaviour sigils (ADR-0026).
##
## Coverage:
##   every catalog entry flagged "behaviour" is handled by SigilEffects, and no other is
##   add_stack / stacks / reset bookkeeping
##   SigilManager routes behaviour ids to SigilEffects and emits sigil_applied
##   afterglow_amount, unravel_radius, siphon_triggers maths
##   nearest() picks the closest living candidate within range
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const CFG: SigilConfig = preload("res://assets/data/sigil_config.tres")


class _FakeEnemy extends Node2D:
	var alive: bool = true
	func is_alive() -> bool:
		return alive


func test_sigil_effects_catalog_behaviour_flags_match_handles() -> void:
	var behaviour_count: int = 0
	for entry: Dictionary in CFG.sigils:
		var id := StringName(entry["id"])
		var flagged: bool = entry.get("behaviour", false)
		assert_bool(SigilEffects.handles(id)).override_failure_message(
			"behaviour flag mismatch for %s" % id).is_equal(flagged)
		if flagged:
			behaviour_count += 1
	assert_int(behaviour_count).is_equal(SigilEffects.IDS.size())


func test_sigil_effects_handles_rejects_stat_and_prana_ids() -> void:
	assert_bool(SigilEffects.handles(&"damage")).is_false()
	assert_bool(SigilEffects.handles(&"prana_1")).is_false()


func test_sigil_effects_add_stack_counts_and_reset_clears() -> void:
	var fx := SigilEffects.new()
	assert_int(fx.stacks(&"riposte")).is_equal(0)
	assert_bool(fx.add_stack(&"riposte")).is_true()
	fx.add_stack(&"riposte")
	fx.add_stack(&"siphon")
	assert_int(fx.stacks(&"riposte")).is_equal(2)
	assert_int(fx.stacks(&"siphon")).is_equal(1)
	fx.reset()
	assert_int(fx.stacks(&"riposte")).is_equal(0)
	assert_int(fx.stacks(&"siphon")).is_equal(0)
	fx.free()


func test_sigil_effects_add_stack_unknown_id_returns_false() -> void:
	var fx := SigilEffects.new()
	assert_bool(fx.add_stack(&"damage")).is_false()
	assert_int(fx.stacks(&"damage")).is_equal(0)
	fx.free()


func test_sigil_manager_routes_behaviour_sigil_to_effects() -> void:
	var sm := SigilManager.new()
	var fx := SigilEffects.new()
	sm.effects = fx
	var received: Array[StringName] = []
	sm.sigil_applied.connect(func(id: StringName) -> void: received.append(id))
	sm.apply_sigil(&"ember_wake")
	assert_int(fx.stacks(&"ember_wake")).is_equal(1)
	assert_array(received).contains_exactly([&"ember_wake"])
	sm.free()
	fx.free()


func test_sigil_manager_behaviour_sigil_without_effects_does_not_emit() -> void:
	var sm := SigilManager.new()
	var received: Array[StringName] = []
	sm.sigil_applied.connect(func(id: StringName) -> void: received.append(id))
	sm.apply_sigil(&"static_halo")
	assert_int(received.size()).is_equal(0)
	sm.free()


func test_sigil_effects_afterglow_amount_scales_and_caps() -> void:
	var max_meter: float = 100.0
	assert_float(SigilEffects.afterglow_amount(0, max_meter, CFG)).is_equal(0.0)
	assert_float(SigilEffects.afterglow_amount(1, max_meter, CFG)).is_equal_approx(
		max_meter * CFG.afterglow_refund, 0.001)
	assert_float(SigilEffects.afterglow_amount(99, max_meter, CFG)).is_equal_approx(
		max_meter * CFG.afterglow_refund_cap, 0.001)


func test_sigil_effects_unravel_radius_grows_half_per_stack() -> void:
	assert_float(SigilEffects.unravel_radius(0, CFG)).is_equal(0.0)
	assert_float(SigilEffects.unravel_radius(1, CFG)).is_equal_approx(CFG.unravel_radius, 0.001)
	assert_float(SigilEffects.unravel_radius(3, CFG)).is_equal_approx(CFG.unravel_radius * 2.0, 0.001)


func test_sigil_effects_siphon_triggers_every_nth_kill() -> void:
	var n: int = CFG.siphon_kills
	assert_bool(SigilEffects.siphon_triggers(0, CFG)).is_false()
	assert_bool(SigilEffects.siphon_triggers(n - 1, CFG)).is_false()
	assert_bool(SigilEffects.siphon_triggers(n, CFG)).is_true()
	assert_bool(SigilEffects.siphon_triggers(n * 2, CFG)).is_true()


func test_sigil_effects_nearest_skips_dead_and_out_of_range() -> void:
	var root := Node2D.new()
	add_child(root)
	var near_dead := _FakeEnemy.new()
	near_dead.position = Vector2(10, 0)
	near_dead.alive = false
	var mid := _FakeEnemy.new()
	mid.position = Vector2(50, 0)
	var far := _FakeEnemy.new()
	far.position = Vector2(500, 0)
	for e: Node in [near_dead, mid, far]:
		root.add_child(e)
	var candidates: Array[Node] = [near_dead, mid, far]
	assert_object(SigilEffects.nearest(Vector2.ZERO, candidates, 200.0)).is_same(mid)
	assert_object(SigilEffects.nearest(Vector2.ZERO, candidates, 20.0)).is_null()
	root.free()
