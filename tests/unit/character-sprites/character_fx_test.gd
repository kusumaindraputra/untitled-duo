## character_fx_test.gd — hit flash, cast pose, death dissolve and native-resolution
## boss sheets (ADR-0034).
extends GdUnitTestSuite

const FAYDE_SHEET: String = "res://assets/art/characters/fayde.png"
const ENEMY_SCENE: String = "res://src/gameplay/EnemyInstance.tscn"
const FX: CharacterFxTuning = preload("res://assets/data/character_fx_tuning.tres")
## Boss type ids: Vault Sentinel, Warped Warden, Cipher Keeper.
const BOSS_IDS: Array[int] = [5, 3, 11]


func _fayde_pc() -> PixelCharacter:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	return pc


func _enemy(type_id: int) -> EnemyInstance:
	var e: EnemyInstance = (load(ENEMY_SCENE) as PackedScene).instantiate()
	e.init(type_id)
	return e


# ── Pure helpers ─────────────────────────────────────────────────────────────

func test_cast_frames_spread_over_the_duration_and_hold_the_last() -> void:
	var start: int = PixelCharacter.ROW_CAST * PixelCharacter.FRAMES
	assert_int(PixelCharacter.cast_frame_for(0.0, 0.4)).is_equal(start)
	assert_int(PixelCharacter.cast_frame_for(0.15, 0.4)).is_equal(start + 1)
	assert_int(PixelCharacter.cast_frame_for(0.25, 0.4)).is_equal(start + 2)
	assert_int(PixelCharacter.cast_frame_for(0.39, 0.4)).is_equal(start + 3)
	assert_int(PixelCharacter.cast_frame_for(5.0, 0.4)).is_equal(start + 3)


func test_flash_holds_full_then_fades_to_zero() -> void:
	assert_float(PixelCharacter.flash_amount_at(0.0, 0.1, 0.4)).is_equal(1.0)
	assert_float(PixelCharacter.flash_amount_at(0.04, 0.1, 0.4)).is_equal(1.0)
	assert_float(PixelCharacter.flash_amount_at(0.07, 0.1, 0.4)).is_equal_approx(0.5, 0.001)
	assert_float(PixelCharacter.flash_amount_at(0.1, 0.1, 0.4)).is_equal(0.0)
	assert_float(PixelCharacter.flash_amount_at(0.0, 0.0, 0.4)).is_equal(0.0)


func test_tuning_dissolve_finishes_before_the_body_is_freed() -> void:
	assert_float(FX.dissolve_sec).is_less(EnemyInstance.BASE_DEATH_DURATION)


func test_hit_flash_colour_is_white() -> void:
	assert_object(FX.hit_flash_color).is_equal(Color.WHITE)


# ── PixelCharacter effects ───────────────────────────────────────────────────

func test_no_shader_material_until_an_effect_runs() -> void:
	var pc := _fayde_pc()
	var body: Sprite2D = pc.get_child(0)
	assert_object(body.material).is_null()
	pc.flash(Color.WHITE, 0.1)
	assert_object(body.material).is_not_null()
	assert_object((pc.get_child(1) as Sprite2D).material).is_same(body.material)
	pc.free()


func test_flash_is_full_then_gone_after_its_duration() -> void:
	var pc := _fayde_pc()
	pc.flash(Color.WHITE, 0.1)
	assert_float(pc.get_flash_amount()).is_equal(1.0)
	var mat: ShaderMaterial = (pc.get_child(0) as Sprite2D).material
	assert_float(mat.get_shader_parameter(&"flash_amount")).is_equal(1.0)
	pc.advance_fx(0.2)
	assert_float(pc.get_flash_amount()).is_equal(0.0)
	assert_float(mat.get_shader_parameter(&"flash_amount")).is_equal(0.0)
	pc.free()


func test_flash_strength_scales_the_amount() -> void:
	var pc := _fayde_pc()
	pc.flash(Color.RED, 0.1, 0.45)
	assert_float(pc.get_flash_amount()).is_equal_approx(0.45, 0.001)
	pc.free()


func test_cast_plays_the_cast_row_then_returns_to_idle() -> void:
	var pc := _fayde_pc()
	pc.play_cast(0.3)
	assert_bool(pc.is_casting()).is_true()
	assert_int(pc.get_frame()).is_equal(PixelCharacter.ROW_CAST * PixelCharacter.FRAMES)
	pc.advance_fx(0.31)
	assert_bool(pc.is_casting()).is_false()
	pc._update_frame()
	assert_int(pc.get_frame() / PixelCharacter.FRAMES).is_equal(PixelCharacter.ROW_IDLE)
	pc.free()


func test_dissolve_runs_to_one_and_emits_once() -> void:
	var pc := _fayde_pc()
	var hits: Array[int] = [0]
	pc.dissolved.connect(func() -> void: hits[0] += 1)
	pc.dissolve(0.5, Color.WHITE)
	assert_float(pc.get_dissolve()).is_equal(0.0)
	pc.advance_fx(0.25)
	assert_float(pc.get_dissolve()).is_equal_approx(0.5, 0.001)
	pc.advance_fx(0.3)
	assert_float(pc.get_dissolve()).is_equal(1.0)
	pc.advance_fx(0.3)
	assert_int(hits[0]).is_equal(1)
	pc.free()


# ── Boss sheets (native resolution) ──────────────────────────────────────────

func test_bosses_use_one_sheet_pixel_per_world_pixel() -> void:
	for id: int in BOSS_IDS:
		var et: EnemyType = EnemyCatalog.get_type(id)
		assert_float(et.sprite_pixel_scale).override_failure_message(et.name).is_equal(1.0)
		assert_object(et.sprite_tint).override_failure_message(et.name).is_equal(Color.WHITE)


func test_boss_sheets_are_large_and_distinct() -> void:
	var seen: Array[Texture2D] = []
	for id: int in BOSS_IDS:
		var et: EnemyType = EnemyCatalog.get_type(id)
		var frame := Vector2i(et.sprite_sheet.get_width() / PixelCharacter.FRAMES,
				et.sprite_sheet.get_height() / PixelCharacter.ROWS)
		assert_int(frame.x).override_failure_message(et.name).is_greater_equal(96)
		assert_object(Vector2i(frame)).override_failure_message(et.name).is_equal(et.sprite_size)
		assert_bool(seen.has(et.sprite_sheet)).override_failure_message(et.name).is_false()
		seen.append(et.sprite_sheet)


# ── Enemy wiring ─────────────────────────────────────────────────────────────

func test_enemy_hit_flash_uses_the_sprite_not_modulate() -> void:
	var e := _enemy(0)
	var pc: PixelCharacter = e.get_node("PixelCharacter")
	e.request_hit_flash()
	assert_float(pc.get_flash_amount()).is_equal(1.0)
	assert_object(e.modulate).is_equal(Color.WHITE)
	e.free()


func test_enemy_windup_plays_the_wind_up_row() -> void:
	var e := _enemy(11)
	add_child(e)
	var pc: PixelCharacter = e.get_node("PixelCharacter")
	var pattern := BulletPattern.new()
	pattern.windup_sec = 0.3
	e._start_windup_flash(pattern)
	assert_bool(pc.is_casting()).is_true()
	if e._windup_tween != null:
		e._windup_tween.kill()
	remove_child(e)
	e.free()


func test_enemy_death_dissolves_the_sprite() -> void:
	var e := _enemy(5)
	var pc: PixelCharacter = e.get_node("PixelCharacter")
	e._dissolve_sprite(GameEnums.DamageClass.NONE)
	pc.advance_fx(FX.dissolve_sec * 0.5)
	assert_float(pc.get_dissolve()).is_greater(0.0)
	var mat: ShaderMaterial = (pc.get_child(0) as Sprite2D).material
	assert_object(mat.get_shader_parameter(&"dissolve_color")).is_equal(FX.dissolve_neutral_color)
	e.free()


# ── Fayde wiring (SpellVFX) ──────────────────────────────────────────────────

func test_fayde_hit_flashes_white_instead_of_turning_red() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	var pc := _fayde_pc()
	pc.name = "PixelCharacter"
	player.add_child(pc)
	add_child(player)
	SpellVFX._on_damage_taken(player, 5, 50)
	assert_float(pc.get_flash_amount()).is_equal(1.0)
	var mat: ShaderMaterial = (pc.get_child(0) as Sprite2D).material
	assert_object(mat.get_shader_parameter(&"flash_color")).is_equal(Color.WHITE)
	assert_object(player.modulate).is_equal(Color.WHITE)
	remove_child(player)
	player.free()
