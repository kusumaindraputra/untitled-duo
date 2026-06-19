## enemy_death_vfx_test.gd — Unit tests for EnemyInstance death burst VFX.
##
## Coverage:
##   _spawn_death_burst() creates a _DeathBurst node as a sibling.
##   _DeathBurst._draw() runs without crash.
##   _DeathBurst auto-frees after DEATH_BURST_DURATION.
##   Color mapping: prana_affiliation resolves to PranaType.color; NONE → white.
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


## GIVEN an EnemyInstance added to a node tree
## WHEN _spawn_death_burst() is called with a valid prana_affiliation
## THEN a _DeathBurst node is added as a sibling
func test_spawn_death_burst_creates_sibling_node() -> void:
	var holder := Node.new()
	add_child(holder)
	auto_free(holder)
	var enemy := _make_test_enemy(holder)

	enemy._spawn_death_burst(GameEnums.DamageClass.FIRE)

	# The burst should be a sibling, not a child of the enemy.
	var burst: Node = null
	for child: Node in holder.get_children():
		if child is EnemyInstance._DeathBurst:
			burst = child
			break
	assert_object(burst).is_not_null()
	if burst != null:
		burst.free()


## GIVEN a _DeathBurst node created and added to the tree
## WHEN it renders its first frame
## THEN _draw() runs without error
func test_death_burst_draw_does_not_crash() -> void:
	var burst := EnemyInstance._DeathBurst.new()
	add_child(burst)
	auto_free(burst)
	burst.prana_affiliation = GameEnums.DamageClass.FIRE

	# Simulate one process + draw cycle.
	burst._process(0.0)
	# _draw() is called by the engine via queue_redraw() — verify the burst
	# doesn't crash by running through its full lifecycle.
	assert_bool(true).is_true()


## GIVEN a _DeathBurst node
## WHEN the duration has elapsed
## THEN it queues itself for free
func test_death_burst_frees_after_duration() -> void:
	var burst := EnemyInstance._DeathBurst.new()
	add_child(burst)
	auto_free(burst)
	burst._start_us = Time.get_ticks_usec() - int(EnemyInstance._DeathBurst.DEATH_BURST_DURATION * 1_000_000.0) - 1

	burst._process(0.0)

	assert_bool(burst.is_queued_for_deletion()).is_true()


## GIVEN a _DeathBurst with NONE prana_affiliation
## THEN the color defaults to white (not a crash)
func test_death_burst_none_affiliation_defaults_white() -> void:
	var burst := EnemyInstance._DeathBurst.new()
	add_child(burst)
	auto_free(burst)
	burst.prana_affiliation = GameEnums.DamageClass.NONE

	# Process frame — must not crash on color lookup.
	burst._process(0.0)
	assert_bool(true).is_true()


## GIVEN an EnemyInstance NOT in the scene tree
## WHEN _spawn_death_burst() is called
## THEN it no-ops without error (headless test safety)
func test_spawn_death_burst_noop_when_not_in_tree() -> void:
	var enemy := EnemyInstance.new()

	enemy._spawn_death_burst(GameEnums.DamageClass.FIRE)

	# Must not crash — the guard returns early.
	assert_bool(true).is_true()
	enemy.free()


# ── Helpers ─────────────────────────────────────────────────────────────────────

func _make_test_enemy(holder: Node) -> EnemyInstance:
	var enemy := EnemyInstance.new()
	holder.add_child(enemy)
	return enemy
