## dash_vfx_test.gd — Unit tests for PlayerController dash VFX (dust + ghosts).
##
## Coverage:
##   _spawn_dash_dust() creates _DashDust nodes when in tree.
##   _DashDust._draw() renders without crash.
##   _DashDust auto-frees after DUST_DURATION.
##   _spawn_dash_dust() no-ops when not in tree.
##   _spawn_dash_ghosts() no-ops when IsoCharacter not initialized.
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


## GIVEN a PlayerController in the scene tree
## WHEN _spawn_dash_dust() is called
## THEN two _DashDust children are added
func test_spawn_dash_dust_creates_two_dust_nodes() -> void:
	var player := PlayerController.new()
	add_child(player)
	auto_free(player)

	player._spawn_dash_dust()

	var dust_count: int = 0
	for child: Node in player.get_children():
		if child is PlayerController._DashDust:
			dust_count += 1
			child.free()
	assert_int(dust_count).is_equal(2)


## GIVEN a _DashDust node
## WHEN the duration has elapsed
## THEN it queues itself for free
func test_dash_dust_frees_after_duration() -> void:
	var dust := PlayerController._DashDust.new()
	add_child(dust)
	auto_free(dust)
	dust._start_us = Time.get_ticks_usec() - int(PlayerController._DashDust.DUST_DURATION * 1_000_000.0) - 1

	dust._process(0.0)

	assert_bool(dust.is_queued_for_deletion()).is_true()


## GIVEN a _DashDust node
## WHEN _process fires
## THEN _draw() runs without crash
func test_dash_dust_draw_does_not_crash() -> void:
	var dust := PlayerController._DashDust.new()
	add_child(dust)
	auto_free(dust)

	dust._process(0.0)
	assert_bool(true).is_true()


## GIVEN a PlayerController NOT in the scene tree
## WHEN _spawn_dash_dust() is called
## THEN it no-ops without error
func test_spawn_dash_dust_noop_when_not_in_tree() -> void:
	var player := PlayerController.new()
	player._spawn_dash_dust()
	assert_bool(true).is_true()
	player.free()


## GIVEN a PlayerController with no IsoCharacter
## WHEN _spawn_dash_ghosts() is called
## THEN it no-ops without crash
func test_spawn_dash_ghosts_noop_when_no_isochar() -> void:
	var player := PlayerController.new()
	add_child(player)
	auto_free(player)

	player._spawn_dash_ghosts(Vector2.RIGHT)

	assert_bool(true).is_true()
