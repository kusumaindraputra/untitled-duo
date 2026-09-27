## squash_stretch_test.gd — sprite squash & stretch on dash, cast and hit (ADR-0040).
##
## Coverage:
##   squash_at starts at the peak, overshoots past rest once, ends exactly at rest
##   squash_peak / stretch_along pick the right axes
##   PixelCharacter.squash scales the sprites (not the node) and settles
##   Reduce motion turns squash off
##   an enemy hit squashes along the blow, a boss less
##   a dash stretches Fayde along the dash
##
## Framework: GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

const FAYDE_SHEET: String = "res://assets/art/characters/fayde.png"
const ENEMY_SCENE: String = "res://src/gameplay/EnemyInstance.tscn"
const FX: CharacterFxTuning = preload("res://assets/data/character_fx_tuning.tres")

var _prev_settings: GameSettings = null


func before_test() -> void:
	_prev_settings = GameSettings.current
	GameSettings.current = null


func after_test() -> void:
	GameSettings.current = _prev_settings


func _fayde_pc() -> PixelCharacter:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	return pc


# ── Pure helpers ─────────────────────────────────────────────────────────────

func test_squash_at_starts_at_peak_and_ends_at_rest() -> void:
	var peak := Vector2(1.2, 0.8)
	assert_bool(PixelCharacter.squash_at(0.0, 0.2, peak).is_equal_approx(peak)).is_true()
	assert_bool(PixelCharacter.squash_at(0.2, 0.2, peak) == Vector2.ONE).is_true()
	assert_bool(PixelCharacter.squash_at(1.0, 0.2, peak) == Vector2.ONE).is_true()
	assert_bool(PixelCharacter.squash_at(0.1, 0.0, peak) == Vector2.ONE).is_true()


func test_squash_at_overshoots_past_rest_once() -> void:
	var peak := Vector2(1.2, 0.8)
	# With one wobble the swing crosses rest at 1/3 and peaks the other way at 2/3.
	var over: Vector2 = PixelCharacter.squash_at(0.2 * 2.0 / 3.0, 0.2, peak, 1.0)
	assert_float(over.x).is_less(1.0)
	assert_float(over.y).is_greater(1.0)
	# ...and the overshoot is smaller than the peak.
	assert_float(1.0 - over.x).is_less(0.2)


func test_squash_peak_is_wide_and_short() -> void:
	assert_bool(PixelCharacter.squash_peak(0.2).is_equal_approx(Vector2(1.2, 0.8))).is_true()
	assert_bool(PixelCharacter.squash_peak(-0.2).is_equal_approx(Vector2(0.8, 1.2))).is_true()


func test_stretch_along_follows_the_direction() -> void:
	var h: Vector2 = PixelCharacter.stretch_along(Vector2.LEFT, 0.25)
	assert_float(h.x).is_greater(1.0)
	assert_float(h.y).is_less(1.0)
	var v: Vector2 = PixelCharacter.stretch_along(Vector2.DOWN, 0.25)
	assert_float(v.y).is_greater(1.0)
	assert_float(v.x).is_less(1.0)
	# A negative amount squashes along the direction instead.
	var hit: Vector2 = PixelCharacter.stretch_along(Vector2.RIGHT, -0.2)
	assert_float(hit.x).is_less(1.0)


# ── PixelCharacter ───────────────────────────────────────────────────────────

func test_squash_scales_the_sprites_not_the_node_then_settles() -> void:
	var pc := _fayde_pc()
	pc.squash(Vector2(1.25, 0.75), 0.2)
	assert_bool(pc._body.scale.is_equal_approx(Vector2(1.25, 0.75))).is_true()
	assert_bool(pc._glow.scale.is_equal_approx(Vector2(1.25, 0.75))).is_true()
	assert_bool(pc.scale == Vector2.ONE).is_true()
	for i: int in range(20):
		pc.advance_fx(0.02)
	assert_bool(pc._body.scale == Vector2.ONE).is_true()
	pc.free()


func test_squash_keeps_pixel_scale() -> void:
	var pc := _fayde_pc()
	pc.pixel_scale = 0.5
	pc.squash(Vector2(1.2, 0.8), 0.2)
	assert_bool(pc._body.scale.is_equal_approx(Vector2(0.6, 0.4))).is_true()
	pc.free()


func test_squash_off_with_reduce_motion() -> void:
	var s := GameSettings.new()
	s.reduce_motion = true
	GameSettings.current = s
	var pc := _fayde_pc()
	pc.squash(Vector2(1.3, 0.7), 0.2)
	assert_bool(pc.get_squash() == Vector2.ONE).is_true()
	assert_bool(pc._body.scale == Vector2.ONE).is_true()
	pc.free()


# ── Enemy hit bounce and Fayde dash ──────────────────────────────────────────

func test_enemy_hit_squashes_along_the_blow() -> void:
	var e: EnemyInstance = (load(ENEMY_SCENE) as PackedScene).instantiate()
	e.init(0)
	var peak: Vector2 = e.hit_squash_peak()
	# No Fayde: a horizontal blow, so the enemy is squashed on x.
	assert_float(peak.x).is_equal_approx(1.0 - FX.enemy_hit_squash, 0.0001)
	assert_float(peak.y).is_equal_approx(1.0 + FX.enemy_hit_squash, 0.0001)
	e.free()


func test_boss_hit_squash_is_smaller() -> void:
	var e: EnemyInstance = (load(ENEMY_SCENE) as PackedScene).instantiate()
	e.init(5)
	assert_bool(e.is_boss()).is_true()
	var peak: Vector2 = e.hit_squash_peak()
	assert_float(1.0 - peak.x).is_equal_approx(FX.enemy_hit_squash * FX.boss_squash_scale, 0.0001)
	e.free()


func test_dash_stretches_fayde_along_the_dash() -> void:
	var player := PlayerController.new()
	# No sheet: the dash then skips the afterimages, which need the scene tree.
	var pc := PixelCharacter.new()
	pc.name = "PixelCharacter"
	player.add_child(pc)
	player._start_dash(Vector2.RIGHT)
	assert_float(pc.get_squash().x).is_greater(1.0)
	assert_float(pc.get_squash().y).is_less(1.0)
	player.free()
