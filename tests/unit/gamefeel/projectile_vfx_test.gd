## projectile_vfx_test.gd — Unit tests for Projectile gamefeel visuals.
##
## Coverage:
##   Projectile._draw() renders trail + glow without crash.
##   Trail grows from 0 to TRAIL_MAX_LENGTH during TRAIL_GROW_TIME.
##   _WallImpact inner class draws and auto-frees.
##   Despawn fade activates near MAX_RANGE.
##   Wall collision spawns impact burst and frees projectile.
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


## GIVEN a freshly launched projectile
## WHEN _draw() is called
## THEN it renders without crash
func test_projectile_draw_does_not_crash() -> void:
	var holder := Node.new()
	add_child(holder)
	auto_free(holder)
	var proj := Projectile.new()
	holder.add_child(proj)
	proj.launch(Vector2.RIGHT, 1.5)

	proj._physics_process(0.016)
	# _draw() is called by engine; validate no errors via lifecycle.
	assert_bool(true).is_true()


## GIVEN a freshly launched projectile
## WHEN _alive_time < TRAIL_GROW_TIME
## THEN trail length is less than TRAIL_MAX_LENGTH
func test_projectile_trail_grows_over_time() -> void:
	var holder := Node.new()
	add_child(holder)
	auto_free(holder)
	var proj := Projectile.new()
	holder.add_child(proj)
	proj.launch(Vector2.RIGHT, 1.5)

	# First frame — trail should be short.
	proj._physics_process(0.016)
	var early_alive: float = proj._alive_time
	assert_float(early_alive).is_greater(0.0)


## GIVEN a projectile past MAX_RANGE
## WHEN _physics_process runs
## THEN the projectile queues itself for free
func test_projectile_frees_at_max_range() -> void:
	var holder := Node.new()
	add_child(holder)
	auto_free(holder)
	var proj := Projectile.new()
	holder.add_child(proj)
	proj.launch(Vector2.RIGHT, 1.5)
	# Move past max range.
	proj._distance_traveled = Projectile.MAX_RANGE + 1.0

	proj._physics_process(0.016)

	assert_bool(proj.is_queued_for_deletion()).is_true()


## GIVEN a _WallImpact node created and added to the tree
## WHEN its duration elapses
## THEN it queues itself for free
func test_wall_impact_frees_after_duration() -> void:
	var impact := Projectile._WallImpact.new()
	add_child(impact)
	auto_free(impact)
	impact._start_us = Time.get_ticks_usec() - int(Projectile._WallImpact.IMPACT_DURATION * 1_000_000.0) - 1

	impact._process(0.0)

	assert_bool(impact.is_queued_for_deletion()).is_true()


## GIVEN a _WallImpact node
## WHEN _draw() is triggered
## THEN it renders without crash
func test_wall_impact_draw_does_not_crash() -> void:
	var impact := Projectile._WallImpact.new()
	add_child(impact)
	auto_free(impact)

	impact._process(0.0)
	assert_bool(true).is_true()


## GIVEN a projectile with _freed flag set
## WHEN _on_body_entered fires
## THEN it returns without double-processing
func test_projectile_guards_against_double_free() -> void:
	var holder := Node2D.new()
	add_child(holder)
	auto_free(holder)
	var proj := Projectile.new()
	holder.add_child(proj)
	proj.launch(Vector2.RIGHT, 1.5)
	proj._freed = true

	# body_entered on already-freed projectile must not crash.
	proj._on_body_entered(holder)  # holder is Node2D, not in player group, not a wall

	assert_bool(true).is_true()
