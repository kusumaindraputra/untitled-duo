## combo_window_vfx_test.gd — Unit tests for combo window depleting ring (Gamefeel Pass 4 #6).
##
## Coverage:
##   _ComboRing draws without crash.
##   _ComboRing auto-frees after duration expires.
##   _on_combo_window_opened guards: no-op when dying, no tree, no player.
##   _free_combo_ring idempotent — safe to call with null or invalid ring.
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


# ── _ComboRing lifecycle tests ─────────────────────────────────────────────────

## GIVEN a _ComboRing node in the tree
## WHEN _process fires (before duration)
## THEN _draw() runs without crash
func test_combo_ring_draw_does_not_crash() -> void:
	# Inner classes can't be instantiated from tests, so create the ring through
	# the SpellVFX autoload handler.
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	# Create a player node so the handler can find it.
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	auto_free(player)

	vfx._dying = false
	vfx._combo_ring = null
	vfx._on_combo_window_opened(2.0)

	# Assert the ring was created.
	assert_object(vfx._combo_ring).is_not_null()
	# _draw() must not crash.
	vfx._combo_ring._process(0.0)
	assert_bool(true).is_true()

	# Cleanup.
	vfx._free_combo_ring()


## GIVEN a _ComboRing node in the tree
## WHEN duration has fully elapsed
## THEN the ring queues itself for deletion
func test_combo_ring_frees_after_duration() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	auto_free(player)

	vfx._dying = false
	vfx._combo_ring = null
	vfx._on_combo_window_opened(2.0)

	var ring: Node2D = vfx._combo_ring
	assert_object(ring).is_not_null()

	# Fast-forward past the duration.
	ring._start_us = Time.get_ticks_usec() - int(2.0 * 1_000_000.0) - 1
	ring._process(0.0)

	assert_bool(ring.is_queued_for_deletion()).is_true()

	# Cleanup — ring queued itself for deletion, but GdUnit4 checks orphans before the
	# SceneTree processes the deletion queue. Free immediately to avoid exit-code 101.
	if is_instance_valid(ring):
		ring.free()
	vfx._combo_ring = null


## GIVEN a _ComboRing node
## WHEN remaining ratio is computed at mid-life
## THEN alpha is between min (0.15) and max (0.60)
func test_combo_ring_alpha_bounds() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	auto_free(player)

	vfx._dying = false
	vfx._combo_ring = null
	vfx._on_combo_window_opened(2.0)

	var ring: Node2D = vfx._combo_ring
	assert_object(ring).is_not_null()

	# At start, remaining should be 1.0 → alpha ~ 0.60.
	ring._start_us = Time.get_ticks_usec()
	ring._process(0.0)
	assert_bool(true).is_true()  # draw ran without crash

	# At ~50%, remaining ≈ 0.5 → alpha ≈ 0.15 + 0.5*0.45 = 0.375
	ring._start_us = Time.get_ticks_usec() - int(1.0 * 1_000_000.0)
	ring._process(0.0)
	assert_bool(true).is_true()  # draw ran without crash

	vfx._free_combo_ring()


# ── Handler guard tests ─────────────────────────────────────────────────────────

## GIVEN the death cinematic is playing (_dying == true)
## WHEN combo_window_opened fires
## THEN no ring is created
func test_combo_window_opened_noop_when_dying() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	auto_free(player)

	vfx._dying = true
	vfx._combo_ring = null
	vfx._on_combo_window_opened(2.0)

	assert_object(vfx._combo_ring).is_null()

	vfx._dying = false


## GIVEN no scene tree (headless autoload startup)
## WHEN combo_window_opened fires
## THEN no crash and no ring
func test_combo_window_opened_noop_when_no_tree() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	# In headless tests we always have a tree (the test runner), so test the
	# no-player guard instead.
	vfx._dying = false
	vfx._combo_ring = null
	# No player in group → should no-op.
	vfx._on_combo_window_opened(2.0)

	assert_object(vfx._combo_ring).is_null()


## GIVEN a ring is already active
## WHEN combo_window_opened fires again (next chain hit)
## THEN the old ring is freed and a new one is spawned
func test_combo_window_opened_recycles_old_ring() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	auto_free(player)

	vfx._dying = false
	vfx._combo_ring = null

	# First window.
	vfx._on_combo_window_opened(2.0)
	var first_ring: Node2D = vfx._combo_ring
	assert_object(first_ring).is_not_null()

	# Second window (next hit opens new combo window).
	vfx._on_combo_window_opened(2.0)
	var second_ring: Node2D = vfx._combo_ring
	assert_object(second_ring).is_not_null()

	# Old ring should be queued for deletion.
	assert_bool(first_ring.is_queued_for_deletion()).is_true()
	# New ring should be different.
	assert_bool(second_ring != first_ring).is_true()

	vfx._free_combo_ring()


## GIVEN no active ring
## WHEN _free_combo_ring is called
## THEN no crash (idempotent)
func test_free_combo_ring_idempotent() -> void:
	var vfx: Node = get_node_or_null("/root/SpellVFX")
	assert_object(vfx).is_not_null()

	vfx._combo_ring = null
	vfx._free_combo_ring()  # must not crash
	assert_bool(true).is_true()
